// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";
import {ILSSVMPairFactoryLike} from "./ILSSVMPairFactoryLike.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";

contract LSSVMRouterWithRoyalties is LSSVMRouter {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeTransferLib for address payable;

    IRoyaltyEngineV1 public constant ROYALTY_ENGINE =
        IRoyaltyEngineV1(0x0385603ab55642cb4Dd5De3aE9e306809991804f);

    mapping(address => uint256) private royaltyRecipientAmounts;
    address[] private royaltyRecipientList;

    constructor(ILSSVMPairFactoryLike _factory) LSSVMRouter(_factory) {}

    /**
        @notice Swaps ETH into specific NFTs using multiple pairs.
        @param swapList The list of pairs to trade with and the IDs of the NFTs to buy from each.
        @param ethRecipient The address that will receive the unspent ETH input
        @param nftRecipient The address that will receive the NFT output
        @param deadline The Unix timestamp (in seconds) at/after which the swap will revert
        @return remainingValue The unspent ETH amount
     */
    function swapETHForSpecificNFTs(
        PairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline
    )
        external
        payable
        override
        checkDeadline(deadline)
        returns (uint256 remainingValue)
    {
        uint256[] memory costs;
        // make swap and save the eth cost for each pair swap
        (remainingValue, costs) = _swapETHForSpecificNFTs(
            swapList,
            msg.value,
            ethRecipient,
            nftRecipient
        );

        uint256 totalRoyalties;
        uint256 numSwaps = swapList.length;

        // loop through swaps
        for (uint256 swapIndex; swapIndex < numSwaps; ) {
            PairSwapSpecific memory swap = swapList[swapIndex];
            IERC721 collection = swap.pair.nft();
            uint256 numNFTs = swap.nftIds.length;

            // even though cost might be incremental between nft buys of a pair
            // the order of the buy doesn't matter, that's why we average the
            // cost of each individual nft bought
            uint256 cost = costs[swapIndex] / numNFTs;

            // loop through each individual nft in the pair swap
            for (uint256 nftIndex; nftIndex < numNFTs; ) {
                // get royalty details from the shared royalty registry
                (
                    address payable[] memory recipients,
                    uint256[] memory amounts
                ) = ROYALTY_ENGINE.getRoyalty(
                        address(collection),
                        swap.nftIds[nftIndex],
                        cost
                    );

                // loop through each royalty recipient
                uint256 numRecipients = recipients.length;
                for (uint256 recipientIndex; recipientIndex < numRecipients; ) {
                    address payable recipient = recipients[recipientIndex];
                    uint256 amount = amounts[recipientIndex];

                    // add the amount that needs to be paid to each recipient in a mapping
                    royaltyRecipientAmounts[recipient] += amount;
                    royaltyRecipientList.push(recipient);
                    totalRoyalties += amount;

                    unchecked {
                        ++recipientIndex;
                    }
                }

                unchecked {
                    ++nftIndex;
                }
            }

            unchecked {
                ++swapIndex;
            }
        }

        // reduce royalties from remaining eth, tx should fail if underflow
        remainingValue -= totalRoyalties;

        // loop through recipients
        uint256 index = royaltyRecipientList.length - 1;
        while (index >= 0) {
            address payable recipient = payable(royaltyRecipientList[index]);
            uint256 amount = royaltyRecipientAmounts[recipient];

            // remove recipient from storage in order to get gas refunds
            royaltyRecipientList.pop();
            delete royaltyRecipientAmounts[recipient];

            // issue payment to recipient
            payable(recipient).safeTransferETH(amount);

            if (index == 0) break;

            unchecked {
                --index;
            }
        }
    }
}
