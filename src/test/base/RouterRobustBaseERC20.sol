// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {RouterRobustBase} from "./RouterRobustBase.sol";

abstract contract RouterRobustBaseERC20 is RouterRobustBase {
  
    function robustSwapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        uint256[] memory maxCostPerPairSwap,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.robustSwapERC20ForAnyNFTs(
                swapList,
                inputAmount,
                maxCostPerPairSwap,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        uint256[] memory maxCostPerPairSwap,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.robustSwapERC20ForSpecificNFTs(
                swapList,
                inputAmount,
                maxCostPerPairSwap,
                nftRecipient,
                deadline
            );
    }
}
