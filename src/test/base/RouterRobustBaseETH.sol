// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {RouterRobustBase} from "./RouterRobustBase.sol";

abstract contract RouterRobustBaseETH is RouterRobustBase {

    function robustSwapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        uint256[] memory maxCostPerPairSwap,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.robustSwapETHForAnyNFTs{value: msg.value}(
                swapList,
                maxCostPerPairSwap,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        uint256[] memory maxCostPerPairSwap,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.robustSwapETHForSpecificNFTs{value: msg.value}(
                swapList,
                maxCostPerPairSwap,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }
}
