// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {XykCurve} from "../../bonding-curves/XykCurve.sol";
import {Test721Enumerable} from "../../mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Configurable} from "./Configurable.sol";

abstract contract UsingXykCurve is Configurable {
    function setupCurve() public override returns (ICurve) {
        return new XykCurve();
    }

    function modifyDelta(uint64 delta) public pure override returns (uint64) {
        return 11;
    }

    function modifySpotPrice(uint56 spotPrice)
        public
        pure
        override
        returns (uint56)
    {
        return 0.01 ether;
    }

    function getParamsForPartialFillTest()
        public
        pure
        override
        returns (uint128 spotPrice, uint128 delta)
    {
        return (0.01 ether, 11);
    }
}
