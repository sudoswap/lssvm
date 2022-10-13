// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BaseRouterRobustSwap} from "../../base/BaseRouterRobustSwap.sol";

abstract contract PNMRouterRobustSwap is PNMBase, BaseRouterRobustSwap {
    function setUp() public override {
        super.setUp();
        targetPair = pair1;
        useDefaultAgent();
    }
}
