// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithAssetRecipient} from "../base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingXykCurve} from "../mixins/UsingXykCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARXykCurveMissingEnumerableETHTest is
    RouterSinglePoolWithAssetRecipient,
    UsingXykCurve,
    UsingMissingEnumerable,
    UsingETH
{}
