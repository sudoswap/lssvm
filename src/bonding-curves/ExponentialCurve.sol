// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

contract ExponentialCurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;

    uint256 public constant MIN_PRICE = 1 gwei;

    function getBuyInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems
    )
        external
        pure
        override
        returns (
            Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        )
    {
        if (delta <= PRBMathUD60x18.SCALE) {
            return (Error.INVALID_DELTA, 0, 0);
        }

        uint256 deltaPowN = delta.powu(numItems);
        newSpotPrice = spotPrice.mul(deltaPowN);
        inputValue = spotPrice.mul(
            (deltaPowN - PRBMathUD60x18.SCALE).div(delta - PRBMathUD60x18.SCALE)
        );
        error = Error.OK;
    }

    function getSellInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems
    )
        external
        pure
        override
        returns (
            Error error,
            uint256 newSpotPrice,
            uint256 outputValue
        )
    {
        if (delta <= PRBMathUD60x18.SCALE) {
            return (Error.INVALID_DELTA, 0, 0);
        }

        uint256 invDelta = delta.inv();
        uint256 invDeltaPowN = invDelta.powu(numItems);
        newSpotPrice = spotPrice.mul(invDeltaPowN);
        if (newSpotPrice < MIN_PRICE) {
            newSpotPrice = MIN_PRICE;
        }
        outputValue = spotPrice.mul(
            (PRBMathUD60x18.SCALE - invDeltaPowN).div(
                PRBMathUD60x18.SCALE - invDelta
            )
        );
        error = Error.OK;
    }
}
