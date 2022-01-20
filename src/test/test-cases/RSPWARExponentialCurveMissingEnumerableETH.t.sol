// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterSinglePoolWithAssetRecipient} from "../base/RouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARExponentialCurveMissingEnumerableETHTest is
    RouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
