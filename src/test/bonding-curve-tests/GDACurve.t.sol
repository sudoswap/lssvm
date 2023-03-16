// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

import {GDACurve} from "../../bonding-curves/GDACurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";

contract GDACurveTest is Test {
    using PRBMathUD60x18 for uint256;
    using Strings for uint256;

    uint256 internal constant _SCALE_FACTOR = 1e9;

    uint256 internal alpha = PRBMathUD60x18.fromUint(15).div(PRBMathUD60x18.fromUint(10));
    uint256 internal lambda = PRBMathUD60x18.fromUint(9).div(PRBMathUD60x18.fromUint(10));

    GDACurve curve;

    function setUp() public {
        curve = new GDACurve();
    }

    function getPackedDelta(uint40 alpha, uint40 lambda, uint48 time) public pure returns (uint128) {
        return ((uint128(alpha) << 88)) | ((uint128(lambda) << 48)) | uint128(time);
    }

    function test_getBuyInfoExample() public {
        vm.warp(10);

        uint40 _alpha = uint40(alpha / _SCALE_FACTOR);
        uint40 _lambda = uint40(lambda / _SCALE_FACTOR);
        uint48 startTime = 5;
        uint128 delta = getPackedDelta(_alpha, _lambda, startTime);

        uint256 numItemsToBuy = 5;
        uint128 spotPrice = 10 ether;
        uint128 adjustedSpotPrice;
        {
            uint128 numItemsAlreadyPurchased = 1; // m = 1
            uint256 alphaPowM = alpha.powu(numItemsAlreadyPurchased);
            adjustedSpotPrice = uint128(uint256(spotPrice).mul(alphaPowM));
        }

        (CurveErrorCodes.Error error, uint128 newSpotPrice, uint128 newDelta, uint256 inputValue, uint256 protocolFee) =
            curve.getBuyInfo(adjustedSpotPrice, delta, numItemsToBuy, 0, 0);

        // Expected delta should have the same alpha and lambda, but different timestamp
        uint128 expectedNewDelta = getPackedDelta(_alpha, _lambda, uint48(10));

        // Calculate expected price using a Python library
        uint256 expectedInputValue = calculatePrice(spotPrice, alpha, lambda, 1, 5, 5);
        uint256 expectedNewSpotPrice = 1265384136934162725;

        assertEq(uint256(error), uint256(CurveErrorCodes.Error.OK), "Error code not OK");
        assertEq(newSpotPrice, expectedNewSpotPrice, "Spot price incorrect");
        assertEq(newDelta, expectedNewDelta, "Delta incorrect");
        assertApproxEqRel(inputValue, expectedInputValue, 1e9, "Input value incorrect");
        assertEq(protocolFee, 0, "Protocol fee incorrect");
    }

    //call out to python script for price computation
    function calculatePrice(
        uint256 _initialPrice,
        uint256 _scaleFactor,
        uint256 _decayConstant,
        uint256 _numTotalPurchases,
        uint256 _timeSinceStart,
        uint256 _quantity
    ) private returns (uint256) {
        string[] memory inputs = new string[](15);
        inputs[0] = "python3";
        inputs[1] = "src/test/gda-analysis/compute_price.py";
        inputs[2] = "exp_discrete";
        inputs[3] = "--initial_price";
        inputs[4] = uint256(_initialPrice).toString();
        inputs[5] = "--scale_factor";
        inputs[6] = uint256(_scaleFactor).toString();
        inputs[7] = "--decay_constant";
        inputs[8] = uint256(_decayConstant).toString();
        inputs[9] = "--num_total_purchases";
        inputs[10] = _numTotalPurchases.toString();
        inputs[11] = "--time_since_start";
        inputs[12] = _timeSinceStart.toString();
        inputs[13] = "--quantity";
        inputs[14] = _quantity.toString();
        bytes memory res = vm.ffi(inputs);
        uint256 price = abi.decode(res, (uint256));
        return price;
    }
}
