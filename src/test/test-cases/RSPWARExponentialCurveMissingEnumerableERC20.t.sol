// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithAssetRecipient} from "../base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPWARExponentialCurveMissingEnumerableERC20Test is
    RouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
