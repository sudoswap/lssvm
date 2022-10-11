// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BaseRouterSinglePoolWithAssetRecipient} from "../../base/BaseRouterSinglePoolWithAssetRecipient.sol";

abstract contract PNMRouterSinglePoolWithAssetRecipient is
    PNMBase,
    BaseRouterSinglePoolWithAssetRecipient
{
    function setUp() public override {
        super.setUp();
        targetPair = sellPair;
    }
}
