// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";

import {Hevm} from "../utils/Hevm.sol";

contract LinearCurveTest is DSTest {
    LinearCurve curve;

    function setUp() public {
        curve = new LinearCurve();
    }

    function test_getBuyInfoExample() public {
        uint256 spotPrice = 3 ether;
        uint256 delta = 0.1 ether;
        uint256 numItems = 5;
        uint256 feeMultiplier = (PRBMathUD60x18.SCALE * 5) / 1000; // 0.5%
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        ) = curve.getBuyInfo(spotPrice, delta, numItems, feeMultiplier);
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );
        assertEq(newSpotPrice, 3.5 ether, "Spot price incorrect");
        assertEq(inputValue, 16.08 ether, "Input value incorrect");
    }

    function test_getBuyInfoWithoutFee(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        if (numItems == 0) {
            return;
        }

        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        ) = curve.getBuyInfo(spotPrice, delta, numItems, 0);
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );

        assertTrue(
            (newSpotPrice > spotPrice && delta > 0) ||
                (newSpotPrice == spotPrice && delta == 0),
            "Price update incorrect"
        );

        assertGe(
            inputValue,
            numItems * uint256(spotPrice),
            "Input value incorrect"
        );
    }

    function test_getSellInfoExample() public {
        uint256 spotPrice = 3 ether;
        uint256 delta = 0.1 ether;
        uint256 numItems = 5;
        uint256 feeMultiplier = (PRBMathUD60x18.SCALE * 5) / 1000; // 0.5%
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputValue
        ) = curve.getSellInfo(spotPrice, delta, numItems, feeMultiplier);
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );
        assertEq(newSpotPrice, 2.5 ether, "Spot price incorrect");
        assertEq(outputValue, 13.93 ether, "Output value incorrect");
    }

    function test_getSellInfoWithoutFee(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        if (numItems == 0) {
            return;
        }

        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputValue
        ) = curve.getSellInfo(spotPrice, delta, numItems, 0);
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );

        uint256 totalPriceDecrease = uint256(delta) * numItems;
        if (spotPrice < totalPriceDecrease) {
            assertEq(
                newSpotPrice,
                0,
                "New spot price not 0 when decrease is greater than current spot price"
            );
        }

        if (spotPrice > 0) {
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
