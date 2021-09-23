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

    function test_getBuyInfoExample() public {
        uint256 spotPrice = 3 ether;
        uint256 delta = 2 * PRBMathUD60x18.SCALE; // 2
        uint256 numItems = 5;
        uint256 feeMultiplier = (PRBMathUD60x18.SCALE * 5) / 1000; // 0.5%
        uint256 protocolFeeMultiplier = (PRBMathUD60x18.SCALE * 3) / 1000; // 0.3%
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputValue,
            uint256 protocolFee
        ) = curve.getBuyInfo(
                spotPrice,
                delta,
                numItems,
                feeMultiplier,
                protocolFeeMultiplier
            );
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );
        assertEq(newSpotPrice, 96 ether, "Spot price incorrect");
        assertEq(inputValue, 187.488 ether, "Input value incorrect");
        assertEq(protocolFee, 0.558 ether, "Protocol fee incorrect");
    }

    function test_getBuyInfoWithoutFee(
        uint128 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public {
        if (
            delta < PRBMathUD60x18.SCALE ||
            numItems > 10 ||
            spotPrice < MIN_PRICE
        ) {
            return;
        }

        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputValue,

        ) = curve.getBuyInfo(spotPrice, delta, numItems, 0, 0);
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

    function test_getSellInfoExample() public {
        uint256 spotPrice = 3 ether;
        uint256 delta = 2 * PRBMathUD60x18.SCALE; // 2
        uint256 numItems = 5;
        uint256 feeMultiplier = (PRBMathUD60x18.SCALE * 5) / 1000; // 0.5%
        uint256 protocolFeeMultiplier = (PRBMathUD60x18.SCALE * 3) / 1000; // 0.3%
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputValue,
            uint256 protocolFee
        ) = curve.getSellInfo(
                spotPrice,
                delta,
                numItems,
                feeMultiplier,
                protocolFeeMultiplier
            );
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );
        assertEq(newSpotPrice, 0.09375 ether, "Spot price incorrect");
        assertEq(outputValue, 5.766 ether, "Output value incorrect");
        assertEq(protocolFee, 0.0174375 ether, "Protocol fee incorrect");
    }

    function test_getSellInfoWithoutFee(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        if (delta < PRBMathUD60x18.SCALE || spotPrice < MIN_PRICE) {
            return;
        }

        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputValue,

        ) = curve.getSellInfo(spotPrice, delta, numItems, 0, 0);
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
