// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithAssetRecipient} from "../base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract RSPWARXykCurveMissingEnumerableERC20Test is
    RouterSinglePoolWithAssetRecipient,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingERC20
{}
