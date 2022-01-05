// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
import {Test721Enumerable} from "../../mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract NoArbLinearCurve is NoArbBondingCurve {

    function setupCurve() public override returns (ICurve) {
        return new LinearCurve();
    }

    function modifyDelta(uint64 delta) public override pure returns (uint64) {
        return delta;
    }

    function modifySpotPrice(uint56 spotPrice) public override pure returns (uint56) {
        return spotPrice;
    }
}
