// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ExponentialCurve} from "../../bonding-curves/ExponentialCurve.sol";
import {Test721Enumerable} from "../../mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract NoArbExponentialCurve is NoArbBondingCurve {
    function setupCurve() public override returns (ICurve) {
        return new ExponentialCurve();
    }

    function modifyDelta(uint64 delta) public pure override returns (uint64) {
        if (delta <= FixedPointMathLib.WAD) {
            return uint64(FixedPointMathLib.WAD + delta + 1);
        } else {
            return delta;
        }
    }

    function modifySpotPrice(uint56 spotPrice)
        public
        pure
        override
        returns (uint56)
    {
        if (spotPrice < 1 gwei) {
            return 1 gwei;
        } else {
            return spotPrice;
        }
    }
}
