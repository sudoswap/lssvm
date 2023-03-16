// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {GDACurve} from "../../bonding-curves/GDACurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";

contract GDACurveTest is Test {
    using FixedPointMathLib for uint256;

    uint256 internal constant HALF_SCALE = 1e9;

    GDACurve curve;

    function setUp() public {
        curve = new GDACurve();
    }

    function getPackedDelta(uint40 alpha, uint40 lambda, uint48 startTime) public pure returns (uint128) {
        return ((uint128(alpha) << 88)) | ((uint128(lambda) << 48)) | uint128(startTime); 
    }

    function test_getBuyInfoExample() public {
        vm.warp(10);

        uint40 alpha = uint40(15 * HALF_SCALE / 10);  // 1.5 * WAD
        uint40 lambda = uint40(9 * HALF_SCALE / 10); // 0.9 * WAD
        uint48 startTime = 5;
        uint128 delta = getPackedDelta(alpha, lambda, startTime);

        uint256 numItemsToBuy = 5;

        uint128 spotPrice = 10 ether;
        uint128 adjustedSpotPrice;
        {
            uint128 numItemsAlreadyPurchased = 1;
            uint256 fullAlpha = alpha * HALF_SCALE;
            uint256 alphaPowM = fullAlpha.fpow(
                numItemsAlreadyPurchased,
                FixedPointMathLib.WAD
            );
            adjustedSpotPrice = uint128(uint256(spotPrice).fmul(alphaPowM, FixedPointMathLib.WAD));
        }

        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 newDelta,
            uint256 inputValue,
            uint256 protocolFee
        ) = curve.getBuyInfo(
                adjustedSpotPrice,
                delta,
                numItemsToBuy,
                0,
                0
            );
        uint128 expectedNewDelta = getPackedDelta(alpha, lambda, uint48(10));
        uint256 expectedInputValue = 2197498377721056255;  // ~2.2 ETH
        uint256 expectedNewSpotPrice = 1265384136934162725;

        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Error code not OK"
        );
        assertEq(newSpotPrice, expectedNewSpotPrice, "Spot price incorrect");
        assertEq(newDelta, expectedNewDelta, "Delta incorrect");
        assertEq(inputValue, expectedInputValue, "Input value incorrect");
        assertEq(protocolFee, 0, "Protocol fee incorrect");
    }
}