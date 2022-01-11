// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RouterBaseERC20} from "../base/RouterBaseERC20.sol";
import {UsingLinearCurve} from "../mixins/UsingLinearCurve.sol";
import {UsingMissingEnumerable} from "../mixins/UsingMissingEnumerable.sol";
import {UsingERC20} from "../mixins/UsingERC20.sol";

contract Test is RouterBaseERC20, UsingLinearCurve, UsingMissingEnumerable, UsingERC20 {}