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

    function test_getBuyInfo(
        uint128 spotPrice,
        uint128 delta,
        uint8 numItems
    ) public {
        (
            LinearCurve.Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        ) = curve.getBuyInfo(spotPrice, delta, numItems);
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
}
