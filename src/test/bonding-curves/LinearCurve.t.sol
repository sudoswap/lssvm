// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";

import {Hevm} from "../utils/Hevm.sol";

contract LinearCurveTest is DSTest {
    LinearCurve curve;

    function setUp() public {
        curve = new LinearCurve();
    }

    function test_getBuyInfoWithoutFee(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        (
            LinearCurve.Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        ) = curve.getBuyInfo(spotPrice, delta, numItems, 0);
        if (numItems > 0) {
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
        } else {
            assertEq(
                uint256(error),
                uint256(CurveErrorCodes.Error.INVALID_NUMITEMS),
                "Error code not INVALID_NUMITEMS"
            );
        }
    }

    function test_getSellInfoWithoutFee(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        (
            LinearCurve.Error error,
            uint256 newSpotPrice,
            uint256 outputValue
        ) = curve.getSellInfo(spotPrice, delta, numItems, 0);
        if (numItems > 0) {
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
        } else {
            assertEq(
                uint256(error),
                uint256(CurveErrorCodes.Error.INVALID_NUMITEMS),
                "Error code not INVALID_NUMITEMS"
            );
        }
    }
}
