// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {CurveErrorCodes} from "./CurveErrorCodes.sol";

interface ICurve {
    function getBuyInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier
    )
        external
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputValue
        );

    function getSellInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier
    )
        external
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputValue
        );
}
