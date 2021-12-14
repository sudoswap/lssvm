// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {ExponentialCurve} from "../bonding-curves/ExponentialCurve.sol";
import {Test721} from "../mocks/Test721.sol";
import {IERC721Mintable} from "./IERC721Mintable.sol";
import {ICurve} from "../bonding-curves/ICurve.sol";
import {LSSVMPairBaseTest} from "./base/LSSVMPairBase.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract LSSVMPairExponentialMissingEnumerableTest is
    DSTest,
    LSSVMPairBaseTest
{
    function setupCurve() public override returns (ICurve) {
        return new ExponentialCurve();
    }

    function setup721() public override returns (IERC721Mintable) {
        return IERC721Mintable(address(new Test721()));
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
