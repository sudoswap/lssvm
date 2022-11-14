// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BaseRouterRobustSwapWithAssetRecipient} from "../../base/BaseRouterRobustSwapWithAssetRecipient.sol";

abstract contract PNMRouterRobustSwapWithAssetRecipient is
    PNMBase,
    BaseRouterRobustSwapWithAssetRecipient
{
    function setUp() public override {
        super.setUp();
        targetPair = sellPair1;
        agent = getAgent();
    }
}
