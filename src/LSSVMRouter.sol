// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {LSSVMPair} from "./LSSVMPair.sol";

contract LSSVMRouter {
    using Address for address payable;

    bytes1 private constant NFT_TRANSFER_START = 0x11;

    struct PairSwapAny {
        LSSVMPair pair;
        uint256 numItems;
    }

    struct PairSwapSpecific {
        LSSVMPair pair;
        uint256[] nftIds;
    }

    struct NFTsForAnyNFTsTrade {
        PairSwapSpecific[] nftToETHTrades;
        PairSwapAny[] ethToNFTTrades;
    }

    struct NFTsForSpecificNFTsTrade {
        PairSwapSpecific[] nftToETHTrades;
        PairSwapSpecific[] ethToNFTTrades;
    }

    // Used for arbitrage across several pools
    struct ETHtoETHTrade {
        PairSwapSpecific[] ethToNFTTrades;
        PairSwapSpecific[] nftToETHTrades;
    }

    modifier checkDeadline(uint256 deadline) {
        _checkDeadline(deadline);
        _;
    }

    /**
        @notice Swaps ETH into NFTs using multiple pairs.
        @param swapList The list of pairs to trade with and the number of NFTs to buy from each.
        @param maxCost The maximum acceptable total ETH cost
        @param ethRecipient The address that will receive the unspent ETH input
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will be revert
        @return remainingValue The unspent ETH amount
     */
    function swapETHForAnyNFTs(
        PairSwapAny[] calldata swapList,
        uint256 maxCost,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    )
        external
        payable
        checkDeadline(deadline)
        returns (uint256 remainingValue)
    {
        return
            _swapETHForAnyNFTs(
                swapList,
                msg.value,
                maxCost,
                ethRecipient,
                nftRecipient
            );
    }

    /**
        @notice Swaps ETH into specific NFTs using multiple pairs.
        @param swapList The list of pairs to trade with and the IDs of the NFTs to buy from each.
        @param maxCost The maximum acceptable total ETH cost
        @param ethRecipient The address that will receive the unspent ETH input
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will be revert
     */
    function swapETHForSpecificNFTs(
        PairSwapSpecific[] calldata swapList,
        uint256 maxCost,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    ) external payable checkDeadline(deadline) {
        _swapETHForSpecificNFTs(
            swapList,
            msg.value,
            maxCost,
            ethRecipient,
            nftRecipient
        );
    }

    /**
        @notice Swaps NFTs into ETH using multiple pairs.
        @param swapList The list of pairs to trade with and the IDs of the NFTs to sell to each.
        @param minOutput The minimum acceptable total ETH received
        @param ethRecipient The address that will receive the ETH output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will be revert
        @return outputAmount The total ETH received
     */
    function swapNFTsForETH(
        PairSwapSpecific[] calldata swapList,
        uint256 minOutput,
        address payable ethRecipient,
        uint256 deadline
    ) external checkDeadline(deadline) returns (uint256 outputAmount) {
        return _swapNFTsForETH(swapList, minOutput, ethRecipient);
    }

    /**
        @notice Swaps one set of NFTs into another set of specific NFTs using multiple pairs, using
        ETH as the intermediary.
        @param trade The struct containing all NFT-to-ETH swaps and ETH-to-NFT swaps.
        @param minOutput The minimum acceptable total excess ETH received
        @param ethRecipient The address that will receive the ETH output
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will be revert
        @return outputAmount The total ETH received
     */
    function swapNFTsForAnyNFTs(
        NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    ) external payable checkDeadline(deadline) returns (uint256 outputAmount) {
        // Swap NFTs for ETH
        // minOutput of swap set to 0 since we're doing an aggregate slippage check
        outputAmount = _swapNFTsForETH(
            trade.nftToETHTrades,
            0,
            payable(address(this))
        );

        // Add extra value to buy NFTs
        outputAmount += msg.value;

        // Swap ETH for any NFTs
        // cost <= maxCost = outputAmount - minOutput, so outputAmount' = outputAmount - cost >= minOutput
        outputAmount = _swapETHForAnyNFTs(
            trade.ethToNFTTrades,
            outputAmount,
            outputAmount - minOutput,
            ethRecipient,
            nftRecipient
        );
    }

    /**
        @notice Swaps one set of NFTs into another set of specific NFTs using multiple pairs, using
        ETH as the intermediary.
        @param trade The struct containing all NFT-to-ETH swaps and ETH-to-NFT swaps.
        @param minOutput The minimum acceptable total excess ETH received
        @param ethRecipient The address that will receive the ETH output
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will be revert
        @return outputAmount The total ETH received
     */
    function swapNFTsForSpecificNFTs(
        NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    ) external payable checkDeadline(deadline) returns (uint256 outputAmount) {
        // Swap NFTs for ETH
        // minOutput of swap set to 0 since we're doing an aggregate slippage check
        outputAmount = _swapNFTsForETH(
            trade.nftToETHTrades,
            0,
            payable(address(this))
        );

        // Add extra value to buy NFTs
        outputAmount += msg.value;

        // Swap ETH for specific NFTs
        // cost <= maxCost = outputAmount - minOutput, so outputAmount' = outputAmount - cost >= minOutput
        outputAmount = _swapETHForSpecificNFTs(
            trade.ethToNFTTrades,
            outputAmount,
            outputAmount - minOutput,
            ethRecipient,
            nftRecipient
        );
    }

    /**
        @notice Swaps ETH to NFTs and then back to ETH again, with the goal of arbitraging between pools
        @param trade The struct containing all ETH-to-NFT swaps and NFT-to-ETH swaps.
        @param maxCost The maximum amount of ETH consumed in the ETH-to-NFT swap
        @param minOutput The minimum acceptable total excess ETH received in the NFT-to-ETH swap
        @param ethRecipient The address that will receive the ETH output
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will be revert
        @return profitAmount The total ETH profit received
     */
    function swapETHtoETH(
        ETHtoETHTrade calldata trade,
        uint256 maxCost,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    ) external payable checkDeadline(deadline) returns (uint256 profitAmount) {
        
        // Assume we get everything we specified in trade.ethToNFTTrades.nftIds
        uint256 remainingValue = _swapETHForSpecificNFTs(
            trade.ethToNFTTrades,
            msg.value,
            maxCost,
            ethRecipient,
            nftRecipient
        );

        // Once we have all the NFTs, send them to the new pool for ETH
        uint256 outputAmount = _swapNFTsForETH(
            trade.nftToETHTrades,
            minOutput,
            ethRecipient 
        );

        // Ensure that outputAmount > maxCost-remainingValue in order for the swap to be profitable
        // Will auto-revert if the below underflows
        profitAmount = outputAmount - (maxCost-remainingValue);
    }

    receive() external payable {}

    // TODO: robust swaps for ETH<>NFT and NFT<>ETH (with specified slippage per swap)
    // requires new internal functions?

    /**
        Internal functions
     */

    function _checkDeadline(uint256 deadline) internal view {
        require(block.timestamp <= deadline, "Deadline passed");
    }

    function _swapETHForAnyNFTs(
        PairSwapAny[] calldata swapList,
        uint256 inputAmount,
        uint256 maxCost,
        address payable ethRecipient,
        address nftRecipient
    ) internal returns (uint256 remainingValue) {
        // The total ETH cost should be at most the minimum of inputAmount and maxCost
        remainingValue = inputAmount > maxCost ? maxCost : inputAmount;

        // Do swaps
        for (uint256 i = 0; i < swapList.length; i++) {
            // We transfer all of the remaining ETH to the pair to avoid
            // computing the cost twice. The extra ETH will be returned
            // to the router after the swap.
            // If the actual total cost exceeds the initial remainingValue,
            // the transaction will automatically be reverted
            // due to math error
            remainingValue -= swapList[i].pair.swapETHForAnyNFTs{
                value: remainingValue
            }(swapList[i].numItems, nftRecipient);
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            ethRecipient.sendValue(remainingValue);
        }
    }

    function _swapETHForSpecificNFTs(
        PairSwapSpecific[] calldata swapList,
        uint256 inputAmount,
        uint256 maxCost,
        address payable ethRecipient,
        address nftRecipient
    ) internal returns (uint256 remainingValue) {
        // The total ETH cost should be at most the minimum of inputAmount and maxCost
        remainingValue = inputAmount > maxCost ? maxCost : inputAmount;

        // Do swaps
        for (uint256 i = 0; i < swapList.length; i++) {
            // We transfer all of the remaining ETH to the pair to avoid
            // computing the cost twice. The extra ETH will be returned
            // to the router after the swap.
            // If the actual total cost exceeds the initial remainingValue,
            // the transaction will automatically be reverted
            // due to math error
            remainingValue -= swapList[i].pair.swapETHForSpecificNFTs{
                value: remainingValue
            }(swapList[i].nftIds, nftRecipient);
        }

        // Return remaining value to sender
        if (remainingValue > 0) {
            ethRecipient.sendValue(remainingValue);
        }
    }

    function _swapNFTsForETH(
        PairSwapSpecific[] calldata swapList,
        uint256 minOutput,
        address payable ethRecipient
    ) internal returns (uint256 outputAmount) {
        // Do swaps
        for (uint256 i = 0; i < swapList.length; i++) {
            // Transfer NFTs directly from sender to pair
            IERC721 nft = swapList[i].pair.nft();

            // Signal transfer start to pair
            bytes memory signal = new bytes(1);
            signal[0] = NFT_TRANSFER_START;
            nft.safeTransferFrom(
                msg.sender,
                address(swapList[i].pair),
                swapList[i].nftIds[0],
                signal
            );

            // Transfer the remaining NFTs
            for (uint256 j = 1; j < swapList[i].nftIds.length; j++) {
                nft.safeTransferFrom(
                    msg.sender,
                    address(swapList[i].pair),
                    swapList[i].nftIds[j]
                );
            }

            // minExpectedETHOutput is set to 0 since we're doing an aggregate slippage check
            outputAmount += swapList[i].pair.routerSwapNFTsForETH(ethRecipient);
        }

        // Slippage check
        require(outputAmount >= minOutput, "outputAmount too low");
    }
}
