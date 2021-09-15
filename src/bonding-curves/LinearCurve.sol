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
        uint256 totalPriceDecrease = delta * numItems;
        if (spotPrice >= totalPriceDecrease) {
            newSpotPrice = spotPrice - totalPriceDecrease;
            outputValue =
                numItems *
                spotPrice -
                (numItems * (numItems - 1) * delta) /
                2;
            error = Error.OK;
        } else {
            error = Error.PRICE_LOWER_BOUND_REACHED;
        }
    }
}
