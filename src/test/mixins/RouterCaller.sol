// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMRouter} from "../../LSSVMRouter.sol";

abstract contract RouterCaller {

    function swapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapNFTsForAnyNFTsThroughToken(
        LSSVMRouter router,
        LSSVMRouter.NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapNFTsForSpecificNFTsThroughToken(
        LSSVMRouter router,
        LSSVMRouter.NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function robustSwapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        uint256[] memory maxCostPerPairSwapPair,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function robustSwapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        uint256[] memory maxCostPerPairSwapPair,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);
}