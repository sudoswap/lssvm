// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePoolWithAssetRecipient} from "./base/PNMRouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPWARExponentialCurveEnumerableERC20Test is
    PNMRouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingERC20
{}
