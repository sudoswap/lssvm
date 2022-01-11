// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {RouterBase} from "./RouterBase.sol";

abstract contract RouterBaseERC20 is RouterBase {
  
    function swapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return router.swapERC20ForAnyNFTs(swapList, inputAmount, nftRecipient, deadline);
    }

    function swapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return router.swapERC20ForSpecificNFTs(swapList, inputAmount, nftRecipient, deadline);
    }
}
