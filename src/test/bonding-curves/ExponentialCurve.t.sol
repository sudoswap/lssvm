// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

import {ExponentialCurve} from "../../bonding-curves/ExponentialCurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";

import {Hevm} from "../utils/Hevm.sol";

contract ExponentialCurveTest is DSTest {
    uint256 constant MIN_PRICE = 1 gwei;

    ExponentialCurve curve;

    function setUp() public {
        curve = new ExponentialCurve();
    }

    function test_getBuyInfoWithoutFee(
        uint128 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public {
        if (delta < PRBMathUD60x18.SCALE || numItems > 10) {
            return;
        }

        (
            ExponentialCurve.Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        ) = curve.getBuyInfo(spotPrice, delta, numItems, 0);
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );

        if (spotPrice > 0 && numItems > 0) {
            assertTrue(
                (newSpotPrice > spotPrice && delta > PRBMathUD60x18.SCALE) ||
                    (newSpotPrice == spotPrice &&
                        delta == PRBMathUD60x18.SCALE),
                "Price update incorrect"
            );
        }

        assertGe(
            inputValue,
            numItems * uint256(spotPrice),
            "Input value incorrect"
        );
    }

    function test_getSellInfoWithoutFee(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        if (delta < PRBMathUD60x18.SCALE) {
            return;
        }

        (
            ExponentialCurve.Error error,
            uint256 newSpotPrice,
            uint256 outputValue
        ) = curve.getSellInfo(spotPrice, delta, numItems, 0);
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );

        if (spotPrice > MIN_PRICE && numItems > 0) {
            assertTrue(
                (newSpotPrice < spotPrice && delta > 0) ||
                    (newSpotPrice == spotPrice && delta == 0),
                "Price update incorrect"
            );
        }

        assertLe(
            outputValue,
            numItems * uint256(spotPrice),
            "Output value incorrect"
        );
    }
}
