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
    function getNFTQuoteForPartialFillBuy(LSSVMPair pair, uint256 numNFTs)
        external
        view
        returns (uint256[] memory)
    {
        require(numNFTs > 0, "Nonzero");
        uint256[] memory prices = new uint256[](numNFTs);
        uint128 spotPrice = pair.spotPrice();
        uint128 delta = pair.delta();
        uint256 fee = pair.fee();
        for (uint256 i; i < numNFTs; i++) {
            uint256 price;
            (, spotPrice, delta, price, ) = pair.bondingCurve().getBuyInfo(
                spotPrice,
                delta,
                1,
                fee,
                pair.factory().protocolFeeMultiplier()
            );
            prices[i] = price;
        }
        uint256[] memory totalPrices = new uint256[](numNFTs);
        totalPrices[0] = prices[prices.length - 1];
        for (uint256 i = 1; i < numNFTs; i++) {
            totalPrices[i] = totalPrices[i - 1] + prices[prices.length - 1 - i];
        }
        return totalPrices;
    }

    /**
      @dev Performs a batch of buys and sells, avoids performing swaps where the price is beyond
      maxCostPerNumNFTs is 0-indexed, i.e. maxCostPerNumNFTs[0] is the max price to buy 1 NFT, and so on
     */
    function robustBuySellWithETHAndPartialFill(
        PairSwapSpecificPartialFill[] calldata buyList,
        PairSwapSpecificPartialFillForToken[] calldata sellList
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
        {
            // Start with all of the ETH sent
            remainingValue = msg.value;
            uint256 numBuys = buyList.length;

            // Try each buy swap
            for (uint256 i; i < numBuys; ) {
                LSSVMPair pair = buyList[i].swapInfo.pair;
                uint256 numNFTs = buyList[i].swapInfo.nftIds.length;
                uint256 spotPrice = pair.spotPrice();

                // If the spot price is at most the expected spot price, then it's likely nothing happened since the tx was submitted
                // We go and optimistically attempt to fill each item using the user supplied max cost
                if (spotPrice <= buyList[i].expectedSpotPrice) {
                    // Total ETH taken from sender cannot msg.value
                    // because otherwise the deduction from remainingValue will fail
                    remainingValue -= pair.swapTokenForSpecificNFTs{
                        value: buyList[i].maxCostPerNumNFTs[numNFTs - 1]
                    }(
                        buyList[i].swapInfo.nftIds,
                        buyList[i].maxCostPerNumNFTs[numNFTs - 1],
                        msg.sender,
                        true,
                        msg.sender
                    );
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
                            buyList[i].maxCostPerNumNFTs
                        );

                    // If no items are fillable, then skip
                    if (numItemsToFill == 0) {
                        continue;
                    } else {

                        // Figure out which items are actually still buyable from the list
                        uint256[] memory fillableIds = _findAvailableIds(
                            pair,
                            numItemsToFill,
                            buyList[i].swapInfo.nftIds
                        );

                        // If we can actually only fill less items...
                        if (fillableIds.length < numItemsToFill) {
                            numItemsToFill = fillableIds.length;
                            // If no IDs are fillable, then skip entirely
                            if (numItemsToFill == 0) {
                                continue;
                            }
                            // Otherwise, adjust the max amt sent to be down
                            (,,,priceToFillAt,) = pair.getBuyNFTQuote(numItemsToFill); 
                        }

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
                    }
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
        // Locally scope the sells
        {
            // Check spot price
            // Do sells
            // Otherwise, find max fillable amt for sell (while being eth balance aware)
            // Then do the sells
            for (uint256 i; i < sellList.length; ) {
                LSSVMPair pair = sellList[i].swapInfo.pair;
                uint256 spotPrice = pair.spotPrice();
                uint256 numNFTs = sellList[i].swapInfo.nftIds.length;

                // If spot price is at least the expected spot price, go ahead and do the swap
                if (spotPrice >= sellList[i].expectedSpotPrice) {
                    pair.swapNFTsForToken(
                        sellList[i].swapInfo.nftIds,
                        sellList[i].minOutputPerNumNFTs[numNFTs - 1],
                        payable(msg.sender),
                        true,
                        msg.sender
                    );
                }
                // Otherwise, run partial fill calculations
                else {
                    (
                        uint256 numItemsToFill,
                        uint256 priceToFillAt
                    ) = _findMaxFillableAmtForETHSell(
                            pair,
                            numNFTs,
                            sellList[i].minOutputPerNumNFTs
                        );
                    pair.swapNFTsForToken(
                        sellList[i].swapInfo.nftIds[0:numItemsToFill],
                        priceToFillAt,
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

            // mid is the index of the max price to buy mid+1 NFTs
            (, , , uint256 currentPrice, ) = pair.getBuyNFTQuote(mid + 1);

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

    function _findMaxFillableAmtForETHSell(
        LSSVMPair pair,
        uint256 maxNumNFTs,
        uint256[] memory minOutputPerNumNFTs
    ) internal view returns (uint256 numNFTs, uint256 price) {
        uint256 pairBalance = address(pair).balance;
        // Start and end indices
        uint256 start = 0;
        uint256 end = maxNumNFTs - 1;
        // while (start <= end) {
        //     // Get price of mid number of items
        //     uint256 mid = start + (end - start + 1) / 2;
        //     (, , , uint256 currentPrice, ) = pair.getSellNFTQuote(mid + 1);
        //     // If it costs more than there is ETH balance for, then recurse on the left half
        //     if (currentPrice > pairBalance) {
        //         if (mid == 1) {
        //             break;
        //         }
        //         end = mid - 1;
        //     }
        //     // Otherwise, we can proceed
        //     else {
        //         // If we can get at least minOutput selling this number of items, recurse on the right half
        //         if (currentPrice >= minOutputPerNumNFTs[mid]) {
        //             numNFTs = mid + 1;
        //             price = currentPrice;
        //             start = mid + 1;
        //         }
        //         // Otherwise, recurse on the left to find something better priced
        //         else {
        //             if (mid == 1) {
        //                 break;
        //             }
        //             end = mid - 1;
        //         }
        //     }
        // }
        // Return numNFTs and price
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
      @dev Buys NFTs first, then sells them.
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
                    buyList[i].maxCost,
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
                // @dev Total ETH taken from sender cannot exceed the starting remainingValue
                // because otherwise the deduction from remainingValue will fail
                remainingValue -= buyList[i]
                    .swapInfo
                    .pair
                    .swapTokenForSpecificNFTs{value: buyList[i].maxCost}(
                    buyList[i].swapInfo.nftIds,
                    buyList[i].maxCost,
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
        @dev Does no price checking, this is assumed to be done off-chain
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

    receive() external payable {}
}
