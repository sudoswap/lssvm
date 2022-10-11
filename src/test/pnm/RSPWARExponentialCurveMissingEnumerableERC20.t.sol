// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePoolWithAssetRecipient} from "./base/PNMRouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPWARExponentialCurveMissingEnumerableERC20Test is
    PNMRouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
