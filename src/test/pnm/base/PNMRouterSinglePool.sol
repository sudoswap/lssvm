// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BaseRouterSinglePool} from "../../base/BaseRouterSinglePool.sol";

abstract contract PNMRouterSinglePool is PNMBase, BaseRouterSinglePool {
    function setUp() public override {
        super.setUp();
        targetPair = pair;
        useDefaultAgent();
    }
}
