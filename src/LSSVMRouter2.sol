// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {ILSSVMPairFactoryLike} from "./ILSSVMPairFactoryLike.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";

contract LSSVMRouter2 {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    struct PairSwapSpecific {
        LSSVMPair pair;
        uint256[] nftIds;
    }

    struct RobustPairSwapSpecific {
        PairSwapSpecific swapInfo;
        uint256 maxCost;
    }

    struct RobustPairSwapSpecificForToken {
        PairSwapSpecific swapInfo;
        uint256 minOutput;
    }

    struct PairSwapSpecificPartialFill {
        PairSwapSpecific swapInfo;
        uint256 expectedSpotPrice;
        uint256[] maxCostPerNumNFTs;
    }

    struct PairSwapSpecificPartialFillForToken {
        PairSwapSpecific swapInfo;
        uint256 expectedSpotPrice;
        uint256[] minOutputPerNumNFTs;
    }

    struct RobustPairNFTsFoTokenAndTokenforNFTsTrade {
        RobustPairSwapSpecific[] tokenToNFTTrades;
        RobustPairSwapSpecificForToken[] nftToTokenTrades;
        uint256 inputAmount;
        address payable tokenRecipient;
        address nftRecipient;
    }

    ILSSVMPairFactoryLike public immutable factory;

    constructor(ILSSVMPairFactoryLike _factory) {
        factory = _factory;
    }

    /**
        @dev Allows a pair contract to transfer ERC721 NFTs directly from
        the sender, in order to minimize the number of token transfers. Only callable by a pair.
        @param nft The ERC721 NFT to transfer
        @param from The address to transfer tokens from
        @param to The address to transfer tokens to
        @param id The ID of the NFT to transfer
        @param variant The pair variant of the pair contract
     */
    function pairTransferNFTFrom(
        IERC721 nft,
        address from,
        address to,
        uint256 id,
        ILSSVMPairFactoryLike.PairVariant variant
    ) external {
        // verify caller is a trusted pair contract
        require(factory.isPair(msg.sender, variant), "Not pair");

        // transfer NFTs to pair
        nft.safeTransferFrom(from, to, id);
    }

    // Given a pair and a number of items to buy, calculate the max price paid for 1 up to numNFTs to buy
    function getNFTQuoteForPartialFill(
        LSSVMPair pair,
        uint256 numNFTs,
        bool isBuy
    ) external view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](numNFTs + 1);
        uint256 fullPrice;
        if (isBuy) {
            (, , , fullPrice, ) = pair.getBuyNFTQuote(numNFTs);
        } else {
            (, , , fullPrice, ) = pair.getSellNFTQuote(numNFTs);
        }
        prices[numNFTs] = fullPrice;
        for (uint256 i = 1; i < numNFTs; i++) {
            uint256 currentPrice;
            if (isBuy) {
                (, , , currentPrice, ) = pair.getBuyNFTQuote(numNFTs - i);
            } else {
                (, , , currentPrice, ) = pair.getSellNFTQuote(numNFTs - i);
            }
            prices[i] = fullPrice - currentPrice;
        }
        return prices;
    }

    /**
      @dev Performs a batch of buys and sells, avoids performing swaps where the price is beyond
     */
    function robustBuySellWithETHAndPartialFill(
        PairSwapSpecificPartialFill[] calldata buyList,
        PairSwapSpecificPartialFillForToken[] calldata sellList
    ) external payable {
        // Go through each buy item
        // Check to see if the quote is as expected
        // If it is, then send that amt over to buy
        // If the quote is more, then check the number of NFTs (presumably less than expected)
        // Take the difference and figure out which ones are still buyable
        // Look up the max cost we're willing to pay
        // Look up the getBuyNFTQuote for the new amount
        // If it is within our bounds, still go ahead and buy
        // Send excess funds back to caller
        // Go through each sell item
        // Check to see if the quote is as expected
        // If it is, then do the NFT->ETH swap
        // (if selling multiple items? --> do the same thing as above for buys?)
        // Otherwise, move on to the next sell attempt

        // Locally scope the buys
        {
            // Start with all of the ETH sent
            uint256 remainingValue = msg.value;
            uint256 numBuys = buyList.length;

            // Try each buy swaps
            for (uint256 i; i < numBuys; ) {
                uint256 spotPrice = buyList[i].swapInfo.pair.spotPrice();

                // If spot price is at most the expected amount, then it's likely nothing happened since the tx was submitted
                // We go and optimistically attempt to fill each one
                if (spotPrice <= buyList[i].expectedSpotPrice) {
                    // Total ETH taken from sender cannot msg.value
                    // because otherwise the deduction from remainingValue will fail
                    remainingValue -= buyList[i]
                        .swapInfo
                        .pair
                        .swapTokenForSpecificNFTs{value: buyList[i].maxCostPerNumNFTs[buyList[i].swapInfo.nftIds.length]}(
                        buyList[i].swapInfo.nftIds,
                        remainingValue,
                        msg.sender,
                        true,
                        msg.sender
                    );
                }
                // If spot price is greater, then potentially 1 or more items have already been bought
                else {
                    // Do binary search on getBuyNFTQuote() from 1 to numItems
                    // the goal is to find the largest number where the quote is still within the user specified max cost
                    // then go through and figure out which items are still fillable
                    // proveed to go and fill them
                }

                unchecked {
                    ++i;
                }
            }

            // Return remaining value to sender
            if (remainingValue > 0) {
                payable(msg.sender).safeTransferETH(remainingValue);
            }
        }
    }

    function _buyWithPartialFill() internal {}

    /**
      @dev Buys the NFTs first, then sells them. Intended to be used for arbitrage.
     */
    function buyNFTsThenSellWithETH(
        RobustPairSwapSpecific[] calldata buyList,
        RobustPairSwapSpecificForToken[] calldata sellList
    ) external payable {
        // Locally scope the buys
        {
            // Start with all of the ETH sent
            uint256 remainingValue = msg.value;
            uint256 numBuys = buyList.length;

            // Do all buy swaps
            for (uint256 i; i < numBuys; ) {
                // Total ETH taken from sender cannot msg.value
                // because otherwise the deduction from remainingValue will fail
                remainingValue -= buyList[i]
                    .swapInfo
                    .pair
                    .swapTokenForSpecificNFTs{value: buyList[i].maxCost}(
                    buyList[i].swapInfo.nftIds,
                    remainingValue,
                    msg.sender,
                    true,
                    msg.sender
                );

                unchecked {
                    ++i;
                }
            }

            // Return remaining value to sender
            if (remainingValue > 0) {
                payable(msg.sender).safeTransferETH(remainingValue);
            }
        }
        // Locally scope the sells
        {
            // Do all sell swaps
            uint256 numSwaps = sellList.length;
            for (uint256 i; i < numSwaps; ) {
                // Do the swap for token and then update outputAmount
                sellList[i].swapInfo.pair.swapNFTsForToken(
                    sellList[i].swapInfo.nftIds,
                    sellList[i].minOutput,
                    payable(msg.sender),
                    true,
                    msg.sender
                );

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
      @dev Intended for reducing upfront capital costs, e.g. swapping NFTs and then using proceeds to buy other NFTs
     */
    function sellNFTsThenBuyWithETH(
        RobustPairSwapSpecific[] calldata buyList,
        RobustPairSwapSpecificForToken[] calldata sellList
    ) external payable {
        uint256 outputAmount = 0;

        // Locally scope the sells
        {
            // Do all sell swaps
            uint256 numSwaps = sellList.length;
            for (uint256 i; i < numSwaps; ) {
                // Do the swap for token and then update outputAmount
                outputAmount += sellList[i].swapInfo.pair.swapNFTsForToken(
                    sellList[i].swapInfo.nftIds,
                    sellList[i].minOutput,
                    payable(address(this)), // Send funds here first
                    true,
                    msg.sender
                );

                unchecked {
                    ++i;
                }
            }
        }

        // Start with all of the ETH sent plus the ETH gained from the sells
        uint256 remainingValue = msg.value + outputAmount;

        // Locally scope the buys
        {
            uint256 numBuys = buyList.length;

            // Do all buy swaps
            for (uint256 i; i < numBuys; ) {
                // @dev Total ETH taken from sender cannot the starting remainingValue
                // because otherwise the deduction from remainingValue will fail
                remainingValue -= buyList[i]
                    .swapInfo
                    .pair
                    .swapTokenForSpecificNFTs{value: buyList[i].maxCost}(
                    buyList[i].swapInfo.nftIds,
                    remainingValue,
                    msg.sender,
                    true,
                    msg.sender
                );

                unchecked {
                    ++i;
                }
            }
        }
        // Return remaining value to sender
        if (remainingValue > 0) {
            payable(msg.sender).safeTransferETH(remainingValue);
        }
    }

    /**
        @dev Does no price checking, this is assumed to be done off-chain
        @param swapList The list of pairs and swap calldata
        @return remainingValue The unspent token amount
     */
    function swapETHForSpecificNFTs(RobustPairSwapSpecific[] calldata swapList)
        external
        payable
        returns (uint256 remainingValue)
    {
        // Start with all of the ETH sent
        remainingValue = msg.value;

        // Do swaps
        uint256 numSwaps = swapList.length;
        for (uint256 i; i < numSwaps; ) {
            // Total ETH taken from sender cannot exceed inputAmount
            // because otherwise the deduction from remainingValue will fail
            remainingValue -= swapList[i]
                .swapInfo
                .pair
                .swapTokenForSpecificNFTs{value: swapList[i].maxCost}(
                swapList[i].swapInfo.nftIds,
                remainingValue,
                msg.sender,
                true,
                msg.sender
            );

            unchecked {
                ++i;
            }
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            payable(msg.sender).safeTransferETH(remainingValue);
        }
    }

    /**
        @notice Swaps NFTs for tokens, designed to be used for 1 token at a time
        @dev Calling with multiple tokens is permitted, BUT minOutput will be 
        far from enough of a safety check because different tokens almost certainly have different unit prices.
        @param swapList The list of pairs and swap calldata 
        @return outputAmount The number of tokens to be received
     */
    function swapNFTsForToken(
        RobustPairSwapSpecificForToken[] calldata swapList
    ) external returns (uint256 outputAmount) {
        // Do swaps
        uint256 numSwaps = swapList.length;
        for (uint256 i; i < numSwaps; ) {
            // Do the swap for token and then update outputAmount
            outputAmount += swapList[i].swapInfo.pair.swapNFTsForToken(
                swapList[i].swapInfo.nftIds,
                swapList[i].minOutput,
                payable(msg.sender),
                true,
                msg.sender
            );

            unchecked {
                ++i;
            }
        }
    }
}
