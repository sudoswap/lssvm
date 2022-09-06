// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
  Coded for Sudoswap with ♥ by

  ██████╗░███████╗███████╗██╗░░░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
  ██╔══██╗██╔════╝██╔════╝██║░░░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
  ██║░░██║█████╗░░█████╗░░██║░░░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
  ██║░░██║██╔══╝░░██╔══╝░░██║░░░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
  ██████╔╝███████╗██║░░░░░██║░░░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
  ╚═════╝░╚══════╝╚═╝░░░░░╚═╝░░░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

  https://defi.sucks
*/

import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IRoyaltyRegistry} from "manifoldxyz/IRoyaltyRegistry.sol";
import {LSSVMRouter, IERC721, ERC20, SafeTransferLib, LSSVMPair, ILSSVMPairFactoryLike, CurveErrorCodes} from "./LSSVMRouter.sol";
import {LSSVMPairERC20} from "./LSSVMPairERC20.sol";

contract LSSVMRouterWithRoyalties is LSSVMRouter {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    enum RoyaltyType {
        ETH,
        ERC20
    }

    event RoyaltyIssued(
        address indexed issuer,
        address indexed pair,
        address indexed recipient,
        uint256 salePrice,
        uint256 royaltyAmount
    );

    IRoyaltyRegistry public constant ROYALTY_REGISTRY =
        IRoyaltyRegistry(0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D);

    uint256 public immutable FETCH_TOKEN_ID;

    constructor(ILSSVMPairFactoryLike _factory) LSSVMRouter(_factory) {
        // used to query the default royalty for a NFT collection
        // allows collection owner to set a particular royalty for this router
        FETCH_TOKEN_ID = uint256(keccak256(abi.encode(address(this))));
    }

    function supportsRoyalty(address collection) external view returns (bool) {
        // get royalty lookup address from the shared royalty registry
        address lookupAddress = ROYALTY_REGISTRY.getRoyaltyLookupAddress(
            address(collection)
        );
        return
            IERC2981(lookupAddress).supportsInterface(
                type(IERC2981).interfaceId
            );
    }

    /**
        Robust Swaps
        These are "robust" versions of the NFT<>Token swap functions which will never revert due to slippage
        Instead, users specify a per-swap max cost. If the price changes more than the user specifies, no swap is attempted. This allows users to specify a batch of swaps, and execute as many of them as possible.
     */

    /**
        @dev We assume msg.value >= sum of values in maxCostPerPair
        @notice Swaps as much ETH for any NFTs as possible, respecting the per-swap max cost.
        @param swapList The list of pairs to trade with and the number of NFTs to buy from each.
        @param ethRecipient The address that will receive the unspent ETH input
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will revert
        @return remainingValue The unspent token amount
     */
    function robustSwapETHForAnyNFTs(
        RobustPairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        checkDeadline(deadline)
        returns (uint256 remainingValue)
    {
        remainingValue = msg.value;

        // Try doing each swap
        uint256 pairCost;
        uint256 numSwaps = swapList.length;
        RobustPairSwapAny calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Locally scoped to avoid stack too deep error
            {
                CurveErrorCodes.Error error;
                // Calculate actual cost per swap
                (error, , , pairCost, ) = swap.swapInfo.pair.getBuyNFTQuote(
                    swap.swapInfo.numItems
                );
                if (error != CurveErrorCodes.Error.OK) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            (
                address royaltyRecipient,
                uint256 royaltyAmount
            ) = _calculateRoyalties(swap.swapInfo.pair, pairCost);

            // If within our maxCost and no error, proceed
            if (pairCost + royaltyAmount <= swap.maxCost) {
                // We know how much ETH to send because we already did the math above
                // So we just send that much
                remainingValue -= swap.swapInfo.pair.swapTokenForAnyNFTs{
                    value: pairCost
                }(
                    swap.swapInfo.numItems,
                    pairCost,
                    nftRecipient,
                    true,
                    msg.sender
                );
                if (royaltyAmount > 0) {
                    remainingValue -= royaltyAmount;
                    payable(royaltyRecipient).safeTransferETH(royaltyAmount);
                    emit RoyaltyIssued(
                        msg.sender,
                        address(swap.swapInfo.pair),
                        royaltyRecipient,
                        pairCost,
                        royaltyAmount
                    );
                }
            }

            unchecked {
                ++i;
            }
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            ethRecipient.safeTransferETH(remainingValue);
        }
    }

    /**
        @dev We assume msg.value >= sum of values in maxCostPerPair
        @param swapList The list of pairs to trade with and the IDs of the NFTs to buy from each.
        @param ethRecipient The address that will receive the unspent ETH input
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will revert
        @return remainingValue The unspent token amount
     */
    function robustSwapETHForSpecificNFTs(
        RobustPairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    )
        public
        payable
        virtual
        override
        checkDeadline(deadline)
        returns (uint256 remainingValue)
    {
        remainingValue = msg.value;
        uint256 pairCost;

        // Try doing each swap
        uint256 numSwaps = swapList.length;
        RobustPairSwapSpecific calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Locally scoped to avoid stack too deep error
            {
                CurveErrorCodes.Error error;
                // Calculate actual cost per swap
                (error, , , pairCost, ) = swap.swapInfo.pair.getBuyNFTQuote(
                    swap.swapInfo.nftIds.length
                );
                if (error != CurveErrorCodes.Error.OK) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            (
                address royaltyRecipient,
                uint256 royaltyAmount
            ) = _calculateRoyalties(swap.swapInfo.pair, pairCost);

            // If within our maxCost and no error, proceed
            if (pairCost + royaltyAmount <= swap.maxCost) {
                // We know how much ETH to send because we already did the math above
                // So we just send that much
                remainingValue -= swap.swapInfo.pair.swapTokenForSpecificNFTs{
                    value: pairCost
                }(
                    swap.swapInfo.nftIds,
                    pairCost,
                    nftRecipient,
                    true,
                    msg.sender
                );

                if (royaltyAmount > 0) {
                    remainingValue -= royaltyAmount;
                    payable(royaltyRecipient).safeTransferETH(royaltyAmount);
                    emit RoyaltyIssued(
                        msg.sender,
                        address(swap.swapInfo.pair),
                        royaltyRecipient,
                        pairCost,
                        royaltyAmount
                    );
                }
            }

            unchecked {
                ++i;
            }
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            ethRecipient.safeTransferETH(remainingValue);
        }
    }

    /**
        @notice Swaps as many ERC20 tokens for any NFTs as possible, respecting the per-swap max cost.
        @param swapList The list of pairs to trade with and the number of NFTs to buy from each.
        @param inputAmount The amount of ERC20 tokens to add to the ERC20-to-NFT swaps
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will revert
        @return remainingValue The unspent token amount

     */
    function robustSwapERC20ForAnyNFTs(
        RobustPairSwapAny[] calldata swapList,
        uint256 inputAmount,
        address nftRecipient,
        uint256 deadline
    )
        external
        virtual
        override
        checkDeadline(deadline)
        returns (uint256 remainingValue)
    {
        remainingValue = inputAmount;
        uint256 pairCost;

        // Try doing each swap
        uint256 numSwaps = swapList.length;
        RobustPairSwapAny calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Calculate actual cost per swap
            {
                CurveErrorCodes.Error error;
                // Calculate actual cost per swap
                (error, , , pairCost, ) = swap.swapInfo.pair.getBuyNFTQuote(
                    swap.swapInfo.numItems
                );
                if (error != CurveErrorCodes.Error.OK) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            (
                address royaltyRecipient,
                uint256 royaltyAmount
            ) = _calculateRoyalties(swap.swapInfo.pair, pairCost);

            // If within our maxCost and no error, proceed
            if (pairCost + royaltyAmount <= swap.maxCost) {
                pairCost = swap.swapInfo.pair.swapTokenForAnyNFTs(
                    swap.swapInfo.numItems,
                    pairCost,
                    nftRecipient,
                    true,
                    msg.sender
                );

                remainingValue -= pairCost;

                if (royaltyAmount > 0) {
                    remainingValue -= royaltyAmount;
                    ERC20 token = LSSVMPairERC20(address(swap.swapInfo.pair))
                        .token();
                    token.safeTransferFrom(
                        msg.sender,
                        royaltyRecipient,
                        royaltyAmount
                    );
                    emit RoyaltyIssued(
                        msg.sender,
                        address(swap.swapInfo.pair),
                        royaltyRecipient,
                        pairCost,
                        royaltyAmount
                    );
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
        @notice Swaps as many ERC20 tokens for specific NFTs as possible, respecting the per-swap max cost.
        @param swapList The list of pairs to trade with and the IDs of the NFTs to buy from each.
        @param inputAmount The amount of ERC20 tokens to add to the ERC20-to-NFT swaps
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will revert
        @return remainingValue The unspent token amount
     */
    function robustSwapERC20ForSpecificNFTs(
        RobustPairSwapSpecific[] calldata swapList,
        uint256 inputAmount,
        address nftRecipient,
        uint256 deadline
    )
        public
        virtual
        override
        checkDeadline(deadline)
        returns (uint256 remainingValue)
    {
        remainingValue = inputAmount;
        uint256 pairCost;

        // Try doing each swap
        uint256 numSwaps = swapList.length;
        RobustPairSwapSpecific calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Locally scoped to avoid stack too deep error
            {
                CurveErrorCodes.Error error;
                // Calculate actual cost per swap
                (error, , , pairCost, ) = swap.swapInfo.pair.getBuyNFTQuote(
                    swap.swapInfo.nftIds.length
                );
                if (error != CurveErrorCodes.Error.OK) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            (
                address royaltyRecipient,
                uint256 royaltyAmount
            ) = _calculateRoyalties(swap.swapInfo.pair, pairCost);

            // If within our maxCost and no error, proceed
            if (pairCost + royaltyAmount <= swap.maxCost) {
                pairCost = swap.swapInfo.pair.swapTokenForSpecificNFTs(
                    swap.swapInfo.nftIds,
                    pairCost,
                    nftRecipient,
                    true,
                    msg.sender
                );

                remainingValue -= pairCost;

                if (royaltyAmount > 0) {
                    remainingValue -= royaltyAmount;
                    ERC20 token = LSSVMPairERC20(address(swap.swapInfo.pair))
                        .token();
                    token.safeTransferFrom(
                        msg.sender,
                        royaltyRecipient,
                        royaltyAmount
                    );
                    emit RoyaltyIssued(
                        msg.sender,
                        address(swap.swapInfo.pair),
                        royaltyRecipient,
                        pairCost,
                        royaltyAmount
                    );
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
        @notice Swaps as many NFTs for tokens as possible, respecting the per-swap min output
        @param swapList The list of pairs to trade with and the IDs of the NFTs to sell to each.
        @param tokenRecipient The address that will receive the token output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will revert
        @return outputAmount The total ETH/ERC20 received
     */
    function robustSwapNFTsForToken(
        RobustPairSwapSpecificForToken[] calldata swapList,
        address payable tokenRecipient,
        uint256 deadline
    )
        public
        virtual
        override
        checkDeadline(deadline)
        returns (uint256 outputAmount)
    {
        // Try doing each swap
        uint256 numSwaps = swapList.length;
        RobustPairSwapSpecificForToken calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            uint256 pairOutput;

            // Locally scoped to avoid stack too deep error
            {
                CurveErrorCodes.Error error;
                (error, , , pairOutput, ) = swap.swapInfo.pair.getSellNFTQuote(
                    swap.swapInfo.nftIds.length
                );
                if (error != CurveErrorCodes.Error.OK) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            (
                address royaltyRecipient,
                uint256 royaltyAmount
            ) = _calculateRoyalties(swap.swapInfo.pair, pairOutput);
            RoyaltyType royaltyType = _fetchRoyaltyType(swap.swapInfo.pair);

            // If at least equal to our minOutput, proceed
            if (pairOutput - royaltyAmount >= swap.minOutput) {
                if (royaltyAmount > 0) {
                    // Do the swap and update outputAmount with how many tokens we got
                    pairOutput = swap.swapInfo.pair.swapNFTsForToken(
                        swap.swapInfo.nftIds,
                        0,
                        payable(address(this)),
                        true,
                        msg.sender
                    );

                    outputAmount += pairOutput - royaltyAmount;

                    if (royaltyType == RoyaltyType.ERC20) {
                        ERC20 token = LSSVMPairERC20(
                            address(swap.swapInfo.pair)
                        ).token();
                        if (royaltyAmount > 0) {
                            token.safeTransfer(royaltyRecipient, royaltyAmount);
                            emit RoyaltyIssued(
                                msg.sender,
                                address(swap.swapInfo.pair),
                                royaltyRecipient,
                                pairOutput,
                                royaltyAmount
                            );
                        }
                        token.safeTransfer(
                            tokenRecipient,
                            pairOutput - royaltyAmount
                        );
                    } else {
                        if (royaltyAmount > 0) {
                            payable(royaltyRecipient).safeTransferETH(
                                royaltyAmount
                            );
                            emit RoyaltyIssued(
                                msg.sender,
                                address(swap.swapInfo.pair),
                                royaltyRecipient,
                                pairOutput,
                                royaltyAmount
                            );
                        }
                        tokenRecipient.safeTransferETH(
                            pairOutput - royaltyAmount
                        );
                    }
                } else {
                    // Do the swap and update outputAmount with how many tokens we got
                    outputAmount += swap.swapInfo.pair.swapNFTsForToken(
                        swap.swapInfo.nftIds,
                        0,
                        tokenRecipient,
                        true,
                        msg.sender
                    );
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
        @notice Buys NFTs with ETH and sells them for tokens in one transaction
        @param params All the parameters for the swap (packed in struct to avoid stack too deep), containing:
        - ethToNFTSwapList The list of NFTs to buy
        - nftToTokenSwapList The list of NFTs to sell
        - inputAmount The max amount of tokens to send (if ERC20)
        - tokenRecipient The address that receives tokens from the NFTs sold
        - nftRecipient The address that receives NFTs
        - deadline UNIX timestamp deadline for the swap
     */
    function robustSwapETHForSpecificNFTsAndNFTsToToken(
        RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    )
        external
        payable
        virtual
        override
        returns (uint256 remainingValue, uint256 outputAmount)
    {
        {
            remainingValue = msg.value;
            uint256 pairCost;
            CurveErrorCodes.Error error;

            // Try doing each swap
            RobustPairSwapSpecific calldata swapIn;
            uint256 numSwaps = params.tokenToNFTTrades.length;
            for (uint256 i; i < numSwaps; ) {
                swapIn = params.tokenToNFTTrades[i];

                // Calculate actual cost per swap
                (error, , , pairCost, ) = swapIn.swapInfo.pair.getBuyNFTQuote(
                    swapIn.swapInfo.nftIds.length
                );

                (
                    address royaltyRecipient,
                    uint256 royaltyAmount
                ) = _calculateRoyalties(swapIn.swapInfo.pair, pairCost);
                // If within our maxCost and no error, proceed
                if (
                    pairCost + royaltyAmount <= swapIn.maxCost &&
                    error == CurveErrorCodes.Error.OK
                ) {
                    // We know how much ETH to send because we already did the math above
                    // So we just send that much
                    pairCost = swapIn.swapInfo.pair.swapTokenForSpecificNFTs{
                        value: pairCost
                    }(
                        swapIn.swapInfo.nftIds,
                        pairCost,
                        params.nftRecipient,
                        true,
                        msg.sender
                    );

                    remainingValue -= pairCost;

                    if (royaltyAmount > 0) {
                        remainingValue -= royaltyAmount;
                        payable(royaltyRecipient).safeTransferETH(
                            royaltyAmount
                        );
                        emit RoyaltyIssued(
                            msg.sender,
                            address(swapIn.swapInfo.pair),
                            royaltyRecipient,
                            pairCost,
                            royaltyAmount
                        );
                    }
                }

                unchecked {
                    ++i;
                }
            }

            // Return remaining value to sender
            if (remainingValue > 0) {
                params.tokenRecipient.safeTransferETH(remainingValue);
            }
        }
        {
            // Try doing each swap
            RobustPairSwapSpecificForToken calldata swapOut;
            uint256 numSwaps = params.nftToTokenTrades.length;
            for (uint256 i; i < numSwaps; ) {
                swapOut = params.nftToTokenTrades[i];

                uint256 pairOutput;

                // Locally scoped to avoid stack too deep error
                {
                    CurveErrorCodes.Error error;
                    (error, , , pairOutput, ) = swapOut
                        .swapInfo
                        .pair
                        .getSellNFTQuote(swapOut.swapInfo.nftIds.length);
                    if (error != CurveErrorCodes.Error.OK) {
                        unchecked {
                            ++i;
                        }
                        continue;
                    }
                }

                (
                    address royaltyRecipient,
                    uint256 royaltyAmount
                ) = _calculateRoyalties(swapOut.swapInfo.pair, pairOutput);
                RoyaltyType royaltyType = _fetchRoyaltyType(
                    swapOut.swapInfo.pair
                );

                // If at least equal to our minOutput, proceed
                if (pairOutput - royaltyAmount >= swapOut.minOutput) {
                    if (royaltyAmount > 0) {
                        // Do the swap and update outputAmount with how many tokens we got
                        pairOutput = swapOut.swapInfo.pair.swapNFTsForToken(
                            swapOut.swapInfo.nftIds,
                            0,
                            payable(address(this)),
                            true,
                            msg.sender
                        );

                        outputAmount += pairOutput - royaltyAmount;

                        if (royaltyType == RoyaltyType.ERC20) {
                            ERC20 token = LSSVMPairERC20(
                                address(swapOut.swapInfo.pair)
                            ).token();
                            if (royaltyAmount > 0) {
                                token.safeTransfer(
                                    royaltyRecipient,
                                    royaltyAmount
                                );
                                emit RoyaltyIssued(
                                    msg.sender,
                                    address(swapOut.swapInfo.pair),
                                    royaltyRecipient,
                                    pairOutput,
                                    royaltyAmount
                                );
                            }
                            token.safeTransfer(
                                params.tokenRecipient,
                                pairOutput - royaltyAmount
                            );
                        } else {
                            if (royaltyAmount > 0) {
                                payable(royaltyRecipient).safeTransferETH(
                                    royaltyAmount
                                );
                                emit RoyaltyIssued(
                                    msg.sender,
                                    address(swapOut.swapInfo.pair),
                                    royaltyRecipient,
                                    pairOutput,
                                    royaltyAmount
                                );
                            }
                            params.tokenRecipient.safeTransferETH(
                                pairOutput - royaltyAmount
                            );
                        }
                    } else {
                        // Do the swap and update outputAmount with how many tokens we got
                        outputAmount += swapOut.swapInfo.pair.swapNFTsForToken(
                            swapOut.swapInfo.nftIds,
                            0,
                            params.tokenRecipient,
                            true,
                            msg.sender
                        );
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
        @notice Buys NFTs with ERC20, and sells them for tokens in one transaction
        @param params All the parameters for the swap (packed in struct to avoid stack too deep), containing:
        - ethToNFTSwapList The list of NFTs to buy
        - nftToTokenSwapList The list of NFTs to sell
        - inputAmount The max amount of tokens to send (if ERC20)
        - tokenRecipient The address that receives tokens from the NFTs sold
        - nftRecipient The address that receives NFTs
        - deadline UNIX timestamp deadline for the swap
     */
    function robustSwapERC20ForSpecificNFTsAndNFTsToToken(
        RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    )
        external
        payable
        virtual
        override
        returns (uint256 remainingValue, uint256 outputAmount)
    {
        {
            remainingValue = params.inputAmount;
            uint256 pairCost;
            CurveErrorCodes.Error error;

            // Try doing each swap
            uint256 numSwaps = params.tokenToNFTTrades.length;
            RobustPairSwapSpecific calldata swapIn;
            for (uint256 i; i < numSwaps; ) {
                swapIn = params.tokenToNFTTrades[i];

                // Calculate actual cost per swap
                (error, , , pairCost, ) = swapIn.swapInfo.pair.getBuyNFTQuote(
                    swapIn.swapInfo.nftIds.length
                );

                (
                    address royaltyRecipient,
                    uint256 royaltyAmount
                ) = _calculateRoyalties(swapIn.swapInfo.pair, pairCost);

                // If within our maxCost and no error, proceed
                if (
                    pairCost + royaltyAmount <= swapIn.maxCost &&
                    error == CurveErrorCodes.Error.OK
                ) {
                    pairCost = swapIn.swapInfo.pair.swapTokenForSpecificNFTs(
                        swapIn.swapInfo.nftIds,
                        pairCost,
                        params.nftRecipient,
                        true,
                        msg.sender
                    );

                    remainingValue -= pairCost;
                    remainingValue -= royaltyAmount;

                    if (royaltyAmount > 0) {
                        ERC20 token = LSSVMPairERC20(
                            address(swapIn.swapInfo.pair)
                        ).token();
                        token.safeTransferFrom(
                            msg.sender,
                            royaltyRecipient,
                            royaltyAmount
                        );
                        emit RoyaltyIssued(
                            msg.sender,
                            address(swapIn.swapInfo.pair),
                            royaltyRecipient,
                            pairCost,
                            royaltyAmount
                        );
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }
        {
            // Try doing each swap
            uint256 numSwaps = params.nftToTokenTrades.length;
            RobustPairSwapSpecificForToken calldata swapOut;
            for (uint256 i; i < numSwaps; ) {
                swapOut = params.nftToTokenTrades[i];

                uint256 pairOutput;

                // Locally scoped to avoid stack too deep error
                {
                    CurveErrorCodes.Error error;
                    (error, , , pairOutput, ) = swapOut
                        .swapInfo
                        .pair
                        .getSellNFTQuote(swapOut.swapInfo.nftIds.length);
                    if (error != CurveErrorCodes.Error.OK) {
                        unchecked {
                            ++i;
                        }
                        continue;
                    }
                }

                (
                    address royaltyRecipient,
                    uint256 royaltyAmount
                ) = _calculateRoyalties(swapOut.swapInfo.pair, pairOutput);
                RoyaltyType royaltyType = _fetchRoyaltyType(
                    swapOut.swapInfo.pair
                );

                // If at least equal to our minOutput, proceed
                if (pairOutput - royaltyAmount >= swapOut.minOutput) {
                    if (royaltyAmount > 0) {
                        // Do the swap and update outputAmount with how many tokens we got
                        pairOutput = swapOut.swapInfo.pair.swapNFTsForToken(
                            swapOut.swapInfo.nftIds,
                            0,
                            payable(address(this)),
                            true,
                            msg.sender
                        );

                        outputAmount += pairOutput - royaltyAmount;

                        if (royaltyType == RoyaltyType.ERC20) {
                            ERC20 token = LSSVMPairERC20(
                                address(swapOut.swapInfo.pair)
                            ).token();
                            if (royaltyAmount > 0) {
                                token.safeTransfer(
                                    royaltyRecipient,
                                    royaltyAmount
                                );
                                emit RoyaltyIssued(
                                    msg.sender,
                                    address(swapOut.swapInfo.pair),
                                    royaltyRecipient,
                                    pairOutput,
                                    royaltyAmount
                                );
                            }
                            token.safeTransfer(
                                params.tokenRecipient,
                                outputAmount
                            );
                        } else {
                            if (royaltyAmount > 0) {
                                payable(royaltyRecipient).safeTransferETH(
                                    royaltyAmount
                                );
                                emit RoyaltyIssued(
                                    msg.sender,
                                    address(swapOut.swapInfo.pair),
                                    royaltyRecipient,
                                    pairOutput,
                                    royaltyAmount
                                );
                            }
                            params.tokenRecipient.safeTransferETH(
                                royaltyAmount
                            );
                        }
                    } else {
                        // Do the swap and update outputAmount with how many tokens we got
                        outputAmount += swapOut.swapInfo.pair.swapNFTsForToken(
                            swapOut.swapInfo.nftIds,
                            0,
                            params.tokenRecipient,
                            true,
                            msg.sender
                        );
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
        @notice Internal function used to swap ETH for any NFTs
        @param swapList The list of pairs and swap calldata
        @param inputAmount The total amount of ETH to send
        @param ethRecipient The address receiving excess ETH
        @param nftRecipient The address receiving the NFTs from the pairs
        @return remainingValue The unspent token amount
     */
    function _swapETHForAnyNFTs(
        PairSwapAny[] calldata swapList,
        uint256 inputAmount,
        address payable ethRecipient,
        address nftRecipient
    ) internal virtual override returns (uint256 remainingValue) {
        remainingValue = inputAmount;

        uint256 pairCost;
        CurveErrorCodes.Error error;

        // Do swaps
        uint256 numSwaps = swapList.length;
        PairSwapAny calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Calculate the cost per swap first to send exact amount of ETH over, saves gas by avoiding the need to send back excess ETH
            (error, , , pairCost, ) = swap.pair.getBuyNFTQuote(swap.numItems);

            // Require no error
            require(error == CurveErrorCodes.Error.OK, "Bonding curve error");

            // Total ETH taken from sender cannot exceed inputAmount
            // because otherwise the deduction from remainingValue will fail
            pairCost = swap.pair.swapTokenForAnyNFTs{value: pairCost}(
                swap.numItems,
                remainingValue,
                nftRecipient,
                true,
                msg.sender
            );

            remainingValue -=
                pairCost +
                _issueETHRoyalties(swap.pair, pairCost);

            unchecked {
                ++i;
            }
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            ethRecipient.safeTransferETH(remainingValue);
        }
    }

    /**
        @notice Internal function used to swap ETH for a specific set of NFTs
        @param swapList The list of pairs and swap calldata
        @param inputAmount The total amount of ETH to send
        @param ethRecipient The address receiving excess ETH
        @param nftRecipient The address receiving the NFTs from the pairs
        @return remainingValue The unspent token amount
     */
    function _swapETHForSpecificNFTs(
        PairSwapSpecific[] calldata swapList,
        uint256 inputAmount,
        address payable ethRecipient,
        address nftRecipient
    ) internal virtual override returns (uint256 remainingValue) {
        remainingValue = inputAmount;

        uint256 pairCost;
        CurveErrorCodes.Error error;

        // Do swaps
        uint256 numSwaps = swapList.length;
        PairSwapSpecific calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Calculate the cost per swap first to send exact amount of ETH over, saves gas by avoiding the need to send back excess ETH
            (error, , , pairCost, ) = swap.pair.getBuyNFTQuote(
                swap.nftIds.length
            );

            // Require no errors
            require(error == CurveErrorCodes.Error.OK, "Bonding curve error");

            // Total ETH taken from sender cannot exceed inputAmount
            // because otherwise the deduction from remainingValue will fail
            pairCost = swap.pair.swapTokenForSpecificNFTs{value: pairCost}(
                swap.nftIds,
                remainingValue,
                nftRecipient,
                true,
                msg.sender
            );

            remainingValue -=
                pairCost +
                _issueETHRoyalties(swap.pair, pairCost);

            unchecked {
                ++i;
            }
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            ethRecipient.safeTransferETH(remainingValue);
        }
    }

    /**
        @notice Internal function used to swap an ERC20 token for any NFTs
        @dev Note that we don't need to query the pair's bonding curve first for pricing data because
        we just calculate and take the required amount from the caller during swap time.
        However, we can't "pull" ETH, which is why for the ETH->NFT swaps, we need to calculate the pricing info
        to figure out how much the router should send to the pool.
        @param swapList The list of pairs and swap calldata
        @param inputAmount The total amount of ERC20 tokens to send
        @param nftRecipient The address receiving the NFTs from the pairs
        @return remainingValue The unspent token amount
     */
    function _swapERC20ForAnyNFTs(
        PairSwapAny[] calldata swapList,
        uint256 inputAmount,
        address nftRecipient
    ) internal virtual override returns (uint256 remainingValue) {
        remainingValue = inputAmount;
        uint256 pairCost;

        // Do swaps
        uint256 numSwaps = swapList.length;
        PairSwapAny calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Tokens are transferred in by the pair calling router.pairTransferERC20From
            // Total tokens taken from sender cannot exceed inputAmount
            // because otherwise the deduction from remainingValue will fail
            pairCost = swap.pair.swapTokenForAnyNFTs(
                swap.numItems,
                remainingValue,
                nftRecipient,
                true,
                msg.sender
            );

            remainingValue -=
                pairCost +
                _issueTokenRoyalties(swap.pair, pairCost);

            unchecked {
                ++i;
            }
        }
    }

    /**
        @notice Internal function used to swap an ERC20 token for specific NFTs
        @dev Note that we don't need to query the pair's bonding curve first for pricing data because
        we just calculate and take the required amount from the caller during swap time.
        However, we can't "pull" ETH, which is why for the ETH->NFT swaps, we need to calculate the pricing info
        to figure out how much the router should send to the pool.
        @param swapList The list of pairs and swap calldata
        @param inputAmount The total amount of ERC20 tokens to send
        @param nftRecipient The address receiving the NFTs from the pairs
        @return remainingValue The unspent token amount
     */
    function _swapERC20ForSpecificNFTs(
        PairSwapSpecific[] calldata swapList,
        uint256 inputAmount,
        address nftRecipient
    ) internal virtual override returns (uint256 remainingValue) {
        remainingValue = inputAmount;
        uint256 pairCost;

        // Do swaps
        uint256 numSwaps = swapList.length;
        PairSwapSpecific calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Tokens are transferred in by the pair calling router.pairTransferERC20From
            // Total tokens taken from sender cannot exceed inputAmount
            // because otherwise the deduction from remainingValue will fail
            pairCost = swap.pair.swapTokenForSpecificNFTs(
                swap.nftIds,
                remainingValue,
                nftRecipient,
                true,
                msg.sender
            );

            remainingValue -=
                pairCost +
                _issueTokenRoyalties(swap.pair, pairCost);

            unchecked {
                ++i;
            }
        }
    }

    /**
        @notice Swaps NFTs for tokens, designed to be used for 1 token at a time
        @dev Calling with multiple tokens is permitted, BUT minOutput will be
        far from enough of a safety check because different tokens almost certainly have different unit prices.
        @param swapList The list of pairs and swap calldata
        @param minOutput The minimum number of tokens to be receieved from the swaps
        @param tokenRecipient The address that receives the tokens
        @return outputAmount The number of tokens to be received
     */
    function _swapNFTsForToken(
        PairSwapSpecific[] calldata swapList,
        uint256 minOutput,
        address payable tokenRecipient
    ) internal virtual override returns (uint256 outputAmount) {
        // Do swaps
        uint256 swapOutputAmount;
        uint256 numSwaps = swapList.length;
        PairSwapSpecific calldata swap;
        for (uint256 i; i < numSwaps; ) {
            swap = swapList[i];

            // Do the swap for token and then update outputAmount
            // Note: minExpectedTokenOutput is set to 0 since we're doing an aggregate slippage check below
            swapOutputAmount = swap.pair.swapNFTsForToken(
                swap.nftIds,
                0,
                payable(address(this)),
                true,
                msg.sender
            );

            RoyaltyType royaltyType = _fetchRoyaltyType(swap.pair);

            ILSSVMPairFactoryLike.PairVariant pairVariant = swap
                .pair
                .pairVariant();

            if (royaltyType == RoyaltyType.ERC20) {
                // avoids using _issueTokenRoyalties internal function because needs ERC20 token for reimbursing to tokenRecipient
                ERC20 token = LSSVMPairERC20(address(swap.pair)).token();

                (
                    address royaltyRecipient,
                    uint256 royaltyAmount
                ) = _calculateRoyalties(swap.pair, swapOutputAmount);

                if (royaltyAmount > 0) {
                    swapOutputAmount -= royaltyAmount;

                    token.safeTransfer(royaltyRecipient, royaltyAmount);
                    emit RoyaltyIssued(
                        msg.sender,
                        address(swap.pair),
                        royaltyRecipient,
                        swapOutputAmount,
                        royaltyAmount
                    );
                }

                token.safeTransfer(address(tokenRecipient), swapOutputAmount);
            } else {
                swapOutputAmount -= _issueETHRoyalties(
                    swap.pair,
                    swapOutputAmount
                );

                tokenRecipient.safeTransferETH(swapOutputAmount);
            }

            outputAmount += swapOutputAmount;

            unchecked {
                ++i;
            }
        }

        // Aggregate slippage check
        require(outputAmount >= minOutput, "outputAmount too low");
    }

    /**
        Royalty querying
        Even though cost might be incremental between nft buys of a pair
        the order of the buy doesn't matter, that's why we aggregate the
        cost of each individual nft bought, and use FETCH_TOKEN_ID to query
        the default royalty info, or a specific set for this router
    */

    function _issueETHRoyalties(LSSVMPair pair, uint256 salePrice)
        internal
        returns (uint256 royalties)
    {
        address recipient;

        (recipient, royalties) = _calculateRoyalties(pair, salePrice);

        if (royalties > 0) {
            // issue payment to recipient
            payable(recipient).safeTransferETH(royalties);
            emit RoyaltyIssued(
                msg.sender,
                address(pair),
                recipient,
                salePrice,
                royalties
            );
        }
    }

    function _issueTokenRoyalties(LSSVMPair pair, uint256 salePrice)
        internal
        returns (uint256 royalties)
    {
        address recipient;

        (recipient, royalties) = _calculateRoyalties(pair, salePrice);

        if (royalties > 0) {
            ERC20 token = LSSVMPairERC20(address(pair)).token();

            // issue payment to royalty recipient
            token.safeTransferFrom(msg.sender, recipient, royalties);
            emit RoyaltyIssued(
                msg.sender,
                address(pair),
                recipient,
                salePrice,
                royalties
            );
        }
    }

    function _calculateRoyalties(LSSVMPair pair, uint256 salePrice)
        internal
        view
        returns (address recipient, uint256 royalties)
    {
        // get royalty lookup address from the shared royalty registry
        address lookupAddress = ROYALTY_REGISTRY.getRoyaltyLookupAddress(
            address(pair.nft())
        );

        // calculates royalty payments for ERC2981 compatible lookup addresses
        if (
            IERC2981(lookupAddress).supportsInterface(
                type(IERC2981).interfaceId
            )
        ) {
            // queries the default royalty (or specific for this router)
            (recipient, royalties) = IERC2981(lookupAddress).royaltyInfo(
                FETCH_TOKEN_ID,
                salePrice
            );

            // validate royalty amount
            require(salePrice >= royalties, "royalty exceeds sale price");
        }
    }

    function _fetchRoyaltyType(LSSVMPair pair)
        internal
        pure
        returns (RoyaltyType)
    {
        ILSSVMPairFactoryLike.PairVariant pairVariant = pair.pairVariant();
        if (pairVariant >= ILSSVMPairFactoryLike.PairVariant.ENUMERABLE_ERC20) {
            return RoyaltyType.ERC20;
        } else {
            return RoyaltyType.ETH;
        }
    }
}
