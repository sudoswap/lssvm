// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";

contract LinearCurve is ICurve, CurveErrorCodes {
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0);
        }

        newSpotPrice = spotPrice + delta * numItems;
        inputValue =
            numItems *
            spotPrice +
            (numItems * (numItems - 1) * delta) /
            2;
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0);
        }

        uint256 totalPriceDecrease = delta * numItems;
        if (spotPrice < totalPriceDecrease) {
            newSpotPrice = 0;
            uint256 numItemsTillZeroPrice = spotPrice / delta;
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

        error = Error.OK;
    }
}
