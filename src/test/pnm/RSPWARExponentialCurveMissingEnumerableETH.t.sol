// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PNMRouterSinglePoolWithAssetRecipient} from "./base/PNMRouterSinglePoolWithAssetRecipient.sol";
import {UsingExponentialCurve} from "../mixins/UsingExponentialCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingETH} from "../mixins/UsingETH.sol";

contract RSPWARExponentialCurveMissingEnumerableETHTest is
    PNMRouterSinglePoolWithAssetRecipient,
    UsingExponentialCurve,
    UsingMissingEnumerable,
    UsingETH
{}
