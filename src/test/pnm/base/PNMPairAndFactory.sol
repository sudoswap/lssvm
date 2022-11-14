// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BasePairAndFactory} from "../../base/BasePairAndFactory.sol";

abstract contract PNMPairAndFactory is PNMBase, BasePairAndFactory {
    function setUp() public override {
        super.setUp();
        targetPair = pair;
        agent = getAgent();
    }
}
