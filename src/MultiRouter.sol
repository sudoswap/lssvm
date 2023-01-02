// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {LSSVMPair} from "./LSSVMPair.sol";
import {ILSSVMPairFactoryLike} from "./ILSSVMPairFactoryLike.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";

contract MultiRouter {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    ILSSVMPairFactoryLike public immutable erc721factory;

    constructor(ILSSVMPairFactoryLike _erc721factory) {
        erc721factory = _erc721factory;
    }

    struct PairSwapSpecific {
        LSSVMPair pair;
        uint256[] nftIds;
    }

    struct PairSwapSpecificPartialFill {
        PairSwapSpecific swapInfo;
        uint256 expectedSpotPrice;
        uint256[] maxCostPerNumNFTs;
        bool isETHSwap;
    }

    struct RobustPairSwapSpecificWithToken {
        PairSwapSpecific swapInfo;
        uint256 maxCost;
        bool isETHSwap;
    }

    struct RobustPairSwapSpecificForToken {
        PairSwapSpecific swapInfo;
        uint256 minOutput;
    }

    struct RobustPairNFTsForTokenAndTokenforNFTsTrade {
        RobustPairSwapSpecificWithToken[] tokenToNFTTradesSpecific;
        RobustPairSwapSpecificForToken[] nftToTokenTrades;
    }

    struct RobustSwapTokensForSpecificNFTsAndPartialFill {
        PairSwapSpecificPartialFill[] buyList;
        uint256 maxItemsToBuy;
    }

    /**
      @dev Performs a log(n) search to find the largest value where maxPricesPerNumNFTs is still greater than 
      the pair's getBuyNFTQuote() value. Not a true binary search, as it's biased to underfill to reduce gas / complexity.
      @param maxNumNFTs The maximum number of NFTs to fill / get a quote for
      @param maxPricesPerNumNFTs The user's specified maximum price to pay for filling a number of NFTs
      @dev Note that maxPricesPerNumNFTs is 0-indexed
     */
    function _findMaxFillableAmtForBuy(
        LSSVMPair pair,
        uint256 maxNumNFTs,
        uint256[] memory maxPricesPerNumNFTs
    ) internal view returns (uint256 numNFTs, uint256 price) {
        // Start and end indices
        uint256 start = 0;
        uint256 end = maxNumNFTs - 1;
        while (start <= end) {
            // Get price of mid number of items
            uint256 mid = start + (end - start) / 2;

            (CurveErrorCodes.Error error, , , uint256 currentPrice, ) = pair
                .getBuyNFTQuote(mid + 1);

            if (error != CurveErrorCodes.Error.OK) {
                break;
            }

            // If we pay at least the currentPrice with our maxPrice, record the value, and recurse on the right half
            if (currentPrice <= maxPricesPerNumNFTs[mid]) {
                // We have to add 1 because mid is indexing into maxPricesPerNumNFTs which is 0-indexed
                numNFTs = mid + 1;
                price = currentPrice;
                start = mid + 1;
            }
            // Otherwise, if it's beyond our budget, recurse on the left half (to find smth cheaper)
            else {
                if (mid == 0) {
                    break;
                }
                end = mid - 1;
            }
        }
        // At the end, we will return the last seen numNFTs and price
    }

    /**
      @dev Checks ownership of all desired NFT IDs to see which ones are still fillable
      @param pair The pair to check
      @param numNFTs The max number of NFTs to check
      @param potentialIds The possible NFT IDs
     */
    function _findAvailableIds(
        LSSVMPair pair,
        uint256 numNFTs,
        uint256[] memory potentialIds
    ) internal view returns (uint256[] memory idsToBuy) {
        IERC721 nft = pair.nft();
        uint256[] memory ids = new uint256[](numNFTs);
        uint256 index = 0;
        // Check to see if each potential ID is still owned by the pair, up to numNFTs items
        for (uint256 i; i < potentialIds.length; ) {
            if (nft.ownerOf(potentialIds[i]) == address(pair)) {
                ids[index] = potentialIds[i];
                unchecked {
                    ++index;
                    if (index == numNFTs) {
                        break;
                    }
                }
            }
            unchecked {
                ++i;
            }
        }
        // Check to see if index is less than numNFTs.
        // If so, then there are less fillable items then expected, and we just copy the first index items over
        // This guarantees no empty spaces in the returned array
        if (index < numNFTs) {
            uint256[] memory idsSubset = new uint256[](index);
            for (uint256 i; i < index; ) {
                idsSubset[i] = ids[i];
                unchecked {
                    ++i;
                }
            }
            return idsSubset;
        }
        return ids;
    }

    /**
      @dev Performs a batch of buys and sells, avoids performing swaps where the price is beyond
      maxCostPerNumNFTs is 0-indexed, i.e. maxCostPerNumNFTs[0] is the max price to buy 1 NFT, and so on
     */
    function robustSwapTokensForSpecificNFTsAndPartialFill(
        RobustSwapTokensForSpecificNFTsAndPartialFill calldata buyParams
    ) external payable returns (uint256 remainingValue) {
        // High level logic:
        // Go through each buy order
        // Check to see if the quote to buy all items is fillable given the max price
        // If it is, then send that amt over to buy
        // If the quote is more expensive than expexted, then figure out the maximum amt to buy to be within maxCost
        // Find a list of IDs still available
        // Make the swap
        // Send excess funds back to caller

        // Locally scope the buys
        // Start with all of the ETH sent
        remainingValue = msg.value;
        uint256 numBuys = buyParams.buyList.length;

        // Variable to keep track of number of individual successful buys
        // It's auto initialized to 0
        uint256 successfulBuyCount;

        // Try each buy swap
        for (uint256 i; i < numBuys; ) {
            LSSVMPair pair = buyParams.buyList[i].swapInfo.pair;

            uint256[] memory nftIdsToBuy = buyParams.buyList[i].swapInfo.nftIds;
            uint256 numNFTs = buyParams.buyList[i].swapInfo.nftIds.length;
            uint256 spotPrice = pair.spotPrice();

            // If the spot price is at most the expected spot price, then it's likely nothing happened since the tx was submitted
            // We go and optimistically attempt to fill each item using the user supplied max cost
            if (spotPrice <= buyParams.buyList[i].expectedSpotPrice) {
                // Check if buying numNFTs will exceed maxItemsToBuy or not
                if (successfulBuyCount + numNFTs > buyParams.maxItemsToBuy) {
                    // If yes, then we need to reduce the number of buys to the desired amount
                    numNFTs = buyParams.maxItemsToBuy - successfulBuyCount;
                    nftIdsToBuy = buyParams
                        .buyList[i]
                        .swapInfo
                        .nftIds[0:numNFTs];
                }

                // We know how much ETH to send because we already did the math above
                // So we just send that much
                if (buyParams.buyList[i].isETHSwap) {
                    // Total ETH taken from sender cannot msg.value
                    // because otherwise the deduction from remainingValue will fail
                    remainingValue -= pair.swapTokenForSpecificNFTs{
                        value: buyParams.buyList[i].maxCostPerNumNFTs[
                            numNFTs - 1
                        ]
                    }(
                        nftIdsToBuy,
                        buyParams.buyList[i].maxCostPerNumNFTs[numNFTs - 1],
                        msg.sender,
                        true,
                        msg.sender
                    );
                }
                // Otherwise we send ERC20 tokens
                else {
                    pair.swapTokenForSpecificNFTs(
                        nftIdsToBuy,
                        buyParams.buyList[i].maxCostPerNumNFTs[numNFTs - 1],
                        msg.sender,
                        true,
                        msg.sender
                    );
                }

                // Increment successfulBuyCount
                successfulBuyCount = successfulBuyCount + numNFTs;
            }
            // If spot price is is greater, then potentially 1 or more items have already been bought
            else {
                // Go through all items to figure out which ones are still buyable
                // We do a halving search on getBuyNFTQuote() from 1 to numNFTs
                // The goal is to find *a* number (not necessarily the largest) where the quote is still within the user specified max cost
                // Then, go through and find as many available items as possible (i.e. still owned by the pair) we can fill
                (
                    uint256 numItemsToFill,
                    uint256 priceToFillAt
                ) = _findMaxFillableAmtForBuy(
                        pair,
                        numNFTs,
                        buyParams.buyList[i].maxCostPerNumNFTs
                    );

                // If no items are fillable, then skip
                if (numItemsToFill == 0) {
                    continue;
                } else {
                    // Check if buying numItemsToFill will exceed maxItemsToBuy or not
                    if (
                        successfulBuyCount + numItemsToFill >
                        buyParams.maxItemsToBuy
                    ) {
                        // If yes, then we need to reduce the number of buys to the desired amount
                        numItemsToFill =
                            buyParams.maxItemsToBuy -
                            successfulBuyCount;
                    }

                    // Figure out which items are actually still buyable from the list
                    uint256[] memory fillableIds = _findAvailableIds(
                        pair,
                        numItemsToFill,
                        buyParams.buyList[i].swapInfo.nftIds
                    );

                    // If we can actually only fill less items...
                    if (fillableIds.length < numItemsToFill) {
                        numItemsToFill = fillableIds.length;
                        // If no IDs are fillable, then skip entirely
                        if (numItemsToFill == 0) {
                            continue;
                        }

                        CurveErrorCodes.Error error;

                        // Otherwise, adjust the max amt sent to be down
                        (error, , , priceToFillAt, ) = pair.getBuyNFTQuote(
                            numItemsToFill
                        );

                        if (error != CurveErrorCodes.Error.OK) {
                            continue;
                        }
                    }

                    // We know how much ETH to send because we already did the math above
                    // So we just send that much
                    if (buyParams.buyList[i].isETHSwap) {
                        // Now, do the partial fill swap with the updated price and ids
                        remainingValue -= pair.swapTokenForSpecificNFTs{
                            value: priceToFillAt
                        }(
                            fillableIds,
                            priceToFillAt,
                            msg.sender,
                            true,
                            msg.sender
                        );
                    } else {
                        pair.swapTokenForSpecificNFTs(
                            fillableIds,
                            priceToFillAt,
                            msg.sender,
                            true,
                            msg.sender
                        );
                    }

                    // Increment successfulBuyCount
                    successfulBuyCount = successfulBuyCount + numNFTs;
                }
            }

            // Check if we have reached maxItemsToBuy
            if (successfulBuyCount >= buyParams.maxItemsToBuy) {
                // If yes, terminate the loop
                break;
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

    /**
        @notice Buys NFTs with ETH and ERC20s and sells them for tokens in one transaction
        @param params All the parameters for the swap (packed in struct to avoid stack too deep), containing:
        - tokenToNFTTradesSpecific The list of NFTs to buy 
        - nftToTokenSwapList The list of NFTs to sell
        - inputAmount The max amount of tokens to send (if ERC20)
        - tokenRecipient The address that receives tokens from the NFTs sold
        - nftRecipient The address that receives NFTs
     */
    function robustSwapTokensForSpecificNFTsAndNFTsToToken(
        RobustPairNFTsForTokenAndTokenforNFTsTrade calldata params
    ) external payable returns (uint256 remainingETHValue) {
        // Attempt to fill each buy order for specific NFTs
        {
            remainingETHValue = msg.value;
            uint256 pairCost;
            CurveErrorCodes.Error error;
            uint256 numSwaps = params.tokenToNFTTradesSpecific.length;
            for (uint256 i; i < numSwaps; ) {
                // Calculate actual cost per swap
                (error, , , pairCost, ) = params
                    .tokenToNFTTradesSpecific[i]
                    .swapInfo
                    .pair
                    .getBuyNFTQuote(
                        params
                            .tokenToNFTTradesSpecific[i]
                            .swapInfo
                            .nftIds
                            .length
                    );

                // If within our maxCost and no error, proceed
                if (
                    pairCost <= params.tokenToNFTTradesSpecific[i].maxCost &&
                    error == CurveErrorCodes.Error.OK
                ) {
                    // We know how much ETH to send because we already did the math above
                    // So we just send that much
                    if (params.tokenToNFTTradesSpecific[i].isETHSwap) {
                        remainingETHValue -= params
                            .tokenToNFTTradesSpecific[i]
                            .swapInfo
                            .pair
                            .swapTokenForSpecificNFTs{value: pairCost}(
                            params.tokenToNFTTradesSpecific[i].swapInfo.nftIds,
                            pairCost,
                            msg.sender,
                            true,
                            msg.sender
                        );
                    }
                    // Otherwise we send ERC20 tokens
                    else {
                        params
                            .tokenToNFTTradesSpecific[i]
                            .swapInfo
                            .pair
                            .swapTokenForSpecificNFTs(
                                params
                                    .tokenToNFTTradesSpecific[i]
                                    .swapInfo
                                    .nftIds,
                                pairCost,
                                msg.sender,
                                true,
                                msg.sender
                            );
                    }
                }

                unchecked {
                    ++i;
                }
            }
            // Return remaining value to sender
            if (remainingETHValue > 0) {
                payable(msg.sender).safeTransferETH(remainingETHValue);
            }
        }
        // Attempt to fill each sell order
        {
            uint256 numSwaps = params.nftToTokenTrades.length;
            for (uint256 i; i < numSwaps; ) {
                uint256 pairOutput;

                // Locally scoped to avoid stack too deep error
                {
                    CurveErrorCodes.Error error;
                    (error, , , pairOutput, ) = params
                        .nftToTokenTrades[i]
                        .swapInfo
                        .pair
                        .getSellNFTQuote(
                            params.nftToTokenTrades[i].swapInfo.nftIds.length
                        );
                    if (error != CurveErrorCodes.Error.OK) {
                        unchecked {
                            ++i;
                        }
                        continue;
                    }
                }

                // If at least equal to our minOutput, proceed
                if (pairOutput >= params.nftToTokenTrades[i].minOutput) {
                    // Do the swap
                    params.nftToTokenTrades[i].swapInfo.pair.swapNFTsForToken(
                        params.nftToTokenTrades[i].swapInfo.nftIds,
                        0,
                        payable(msg.sender),
                        true,
                        msg.sender
                    );
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    receive() external payable {}

    /**
        Restricted functions
     */

    /**
        @dev Allows an ERC20 pair contract to transfer ERC20 tokens directly from
        the sender, in order to minimize the number of token transfers. Only callable by an ERC20 pair.
        @param token The ERC20 token to transfer
        @param from The address to transfer tokens from
        @param to The address to transfer tokens to
        @param amount The amount of tokens to transfer
        @param variant The pair variant of the pair contract
     */
    function pairTransferERC20From(
        ERC20 token,
        address from,
        address to,
        uint256 amount,
        uint8 variant
    ) external {
        // verify caller is an ERC20 pair contract
        ILSSVMPairFactoryLike.PairVariant _variant = ILSSVMPairFactoryLike
            .PairVariant(variant);
        require(erc721factory.isPair(msg.sender, _variant), "Not pair");

        // verify caller is an ERC20 pair
        require(
            _variant == ILSSVMPairFactoryLike.PairVariant.ENUMERABLE_ERC20 ||
                _variant ==
                ILSSVMPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ERC20,
            "Not ERC20 pair"
        );
        // transfer tokens to pair
        token.safeTransferFrom(from, to, amount);
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
        require(erc721factory.isPair(msg.sender, variant), "Not pair");
        // transfer NFTs to pair
        nft.safeTransferFrom(from, to, id);
    }
}
