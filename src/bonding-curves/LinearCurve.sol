// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

contract LinearCurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;

    function validateDelta(
        uint256 /*delta*/
    ) external pure override returns (bool valid) {
        return true;
    }

    function getBuyInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0);
        }

        newSpotPrice = spotPrice + delta * numItems;
        uint256 buySpotPrice = spotPrice + delta;
        inputValue =
            numItems *
            buySpotPrice +
            (numItems * (numItems - 1) * delta) /
            2;
        inputValue += inputValue.mul(feeMultiplier);
        error = Error.OK;
    }

    function getSellInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0);
        }

        uint256 totalPriceDecrease = delta * numItems;
        if (spotPrice < totalPriceDecrease) {
            newSpotPrice = 0;
            uint256 numItemsTillZeroPrice = spotPrice / delta + 1;
            outputValue =
                numItemsTillZeroPrice *
                spotPrice -
                (numItemsTillZeroPrice * (numItemsTillZeroPrice - 1) * delta) /
                2;
        } else {
            newSpotPrice = spotPrice - totalPriceDecrease;
            outputValue =
                numItems *
                spotPrice -
                (numItems * (numItems - 1) * delta) /
                2;
        }
        outputValue -= outputValue.mul(feeMultiplier);

        error = Error.OK;
    }
}
