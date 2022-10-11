// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BaseRouterMultiPool} from "../../base/BaseRouterMultiPool.sol";

// Gives more realistic scenarios where swaps have to go through multiple pools, for more accurate gas profiling
abstract contract PNMRouterMultiPool is PNMBase, BaseRouterMultiPool {
    function setUp() public override {
        super.setUp();
        targetPair = pairs[0];
    }
}
