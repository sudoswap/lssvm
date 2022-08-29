// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IRoyaltyRegistry} from "royalty-registry/IRoyaltyRegistry.sol";
import {EIP2981RoyaltyOverrideCore} from "royalty-registry/overrides/RoyaltyOverrideCore.sol";
import {ILSSVMPairFactoryLike} from "./ILSSVMPairFactoryLike.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";

contract LSSVMRouterWithRoyalties is LSSVMRouter {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeTransferLib for address payable;

    IRoyaltyRegistry public constant ROYALTY_REGISTRY =
        IRoyaltyRegistry(0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D);

    mapping(address => uint256) private royaltyRecipientAmounts;
    address[] private royaltyRecipientList;

    constructor(ILSSVMPairFactoryLike _factory) LSSVMRouter(_factory) {}

    /*
    TODO: add view to read from frontend:
    function supportsEIP2981RoyaltyOverrideCore() external view;
    */

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

        uint256 numSwaps = swapList.length;
        // loop through swaps
        for (uint256 swapIndex; swapIndex < numSwaps; ) {
            PairSwapSpecific memory swap = swapList[swapIndex];
            IERC721 collection = swap.pair.nft();

            // even though cost might be incremental between nft buys of a pair
            // the order of the buy doesn't matter, that's why we average the
            // cost of each individual nft bought
            uint256 cost = costs[swapIndex];

            // get royalty lookup address from the shared royalty registry
            address _lookupAddress = ROYALTY_REGISTRY.getRoyaltyLookupAddress(
                address(collection)
            );

            /*
            TODO: add if {} else {dont process royalties}

            IERC2981(_lookupAddress).supportsInterface(type(EIP2981RoyaltyOverrideCore).interfaceId);
            */

            // queries the default royalty from the lookup address
            (address recepient, uint16 bps) = EIP2981RoyaltyOverrideCore(
                _lookupAddress
            ).defaultRoyalty();

            // calculates the total royalty per batch of NFTs
            uint256 amount = (costs[swapIndex] * bps) / 10_000;

            // reduce royalties from remaining eth, tx should fail if underflow
            remainingValue -= amount;

            // issue payment to recipient
            payable(recepient).safeTransferETH(amount);

            /* NOTE: optional
            event ProcessedRoyalties(address collection, address recepient, uint256[] tokenIds, uint256 cost, uint256 royaltyAmount);

            emit ProcessedRoyalties(collection, recepient, swap.nftIds, cost, amount);
            */

            unchecked {
                ++swapIndex;
            }
        }
    }
}
