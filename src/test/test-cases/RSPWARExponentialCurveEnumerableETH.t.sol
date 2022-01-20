// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithAssetRecipient} from "../base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingEnumerable} from "../mixins/UsingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARExponentialCurveEnumerableETHTest is
    RouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingEnumerable,
    UsingETH
{}
