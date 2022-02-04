// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/*
    @author 0xmons and boredGenius
    @notice Bonding curve logic for an exponential curve, where each buy/sell changes spot price by multiplying/dividing delta
*/
contract ExponentialCurve is ICurve, CurveErrorCodes {
    using FixedPointMathLib for uint256;

    // minimum price to prevent numerical issues 
    uint256 public constant MIN_PRICE = 1 gwei;

    /**
        @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint256 delta)
        external
        pure
        override
        returns (bool)
    {
        return delta > FixedPointMathLib.WAD;
    }

    /**
        @dev See {ICurve-validateSpotPrice}
     */
    function validateSpotPrice(uint256 newSpotPrice)
        external
        pure
        override
        returns (bool)
    {
        return newSpotPrice >= MIN_PRICE;
    }

    /**
        @dev See {ICurve-getBuyInfo}
     */
    function getBuyInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        override
        returns (
            Error error,
            uint256 newSpotPrice,
            uint256 inputValue,
            uint256 protocolFee
        )
    {

        // We only calculate changes for buying 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0);
        }

        uint256 deltaPowN = delta.fpow(numItems, FixedPointMathLib.WAD);

        // For an exponential curve, the spot price is multiplied by delta for each item bought
        newSpotPrice = spotPrice.fmul(deltaPowN, FixedPointMathLib.WAD);

        // Spot price is assumed to be the instant sell price. To avoid arbitraging LPs, we adjust the buy price upwards.
        // If spot price for buy and sell were the same, then someone could buy 1 NFT and then sell for immediate profit.
        // EX: Let S be spot price. Then buying 1 NFT costs S ETH, now new spot price is (S * delta).
        // The same person could then sell for (S * delta) ETH, netting them delta ETH profit.
        // If spot price for buy and sell differ by delta, then buying costs (S * delta) ETH.
        // The new spot price would become (S * delta), so selling would also yield (S * delta) ETH.
        uint256 buySpotPrice = spotPrice.fmul(delta, FixedPointMathLib.WAD);

        // If the user buys n items, then the total cost is equal to:
        // buySpotPrice + (delta * buySpotPrice) + (delta^2 * buySpotPrice) + ... (delta^(numItems - 1) * buySpotPrice)
        // This is equal to buySpotPrice * (delta^n - 1) / (delta - 1)
        inputValue = buySpotPrice.fmul(
            (deltaPowN - FixedPointMathLib.WAD).fdiv(
                delta - FixedPointMathLib.WAD,
                FixedPointMathLib.WAD
            ),
            FixedPointMathLib.WAD
        );

        // Account for the protocol fee, a flat percentage of the buy amount
        protocolFee = inputValue.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );

        // Account for the trade fee, only for Trade pools
        inputValue += inputValue.fmul(feeMultiplier, FixedPointMathLib.WAD);

        // Add the protocol fee to the required input amount
        inputValue += protocolFee;

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    /**
        @dev See {ICurve-getSellInfo}
        If newSpotPrice is less than MIN_PRICE, newSpotPrice is set to MIN_PRICE instead.
        This is to prevent the spot price from ever becoming 0, which would decouple the price
        from the bonding curve (since 0 * delta is still 0)
     */
    function getSellInfo(
        uint256 spotPrice,
        uint256 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        override
        returns (
            Error error,
            uint256 newSpotPrice,
            uint256 outputValue,
            uint256 protocolFee
        )
    {
        // We only calculate changes for buying 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0);
        }

        uint256 invDelta = FixedPointMathLib.WAD.fdiv(
            delta,
            FixedPointMathLib.WAD
        );
        uint256 invDeltaPowN = invDelta.fpow(numItems, FixedPointMathLib.WAD);

        // For an exponential curve, the spot price is divided by delta for each item sold
        newSpotPrice = spotPrice.fmul(invDeltaPowN, FixedPointMathLib.WAD);
        if (newSpotPrice < MIN_PRICE) {
            newSpotPrice = MIN_PRICE;
        }

        // If the user sells n items, then the total revenue is equal to:
        // spotPrice + ((1 / delta) * spotPrice) + ((1 / delta)^2 * spotPrice) + ... ((1 / delta)^(numItems - 1) * spotPrice)
        // This is equal to spotPrice * (1 - (1 / delta^n)) / (1 - (1 / delta))
        outputValue = spotPrice.fmul(
            (FixedPointMathLib.WAD - invDeltaPowN).fdiv(
                FixedPointMathLib.WAD - invDelta,
                FixedPointMathLib.WAD
            ),
            FixedPointMathLib.WAD
        );

        // Account for the protocol fee, a flat percentage of the sell amount
        protocolFee = outputValue.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );

        // Account for the trade fee, only for Trade pools
        outputValue -= outputValue.fmul(feeMultiplier, FixedPointMathLib.WAD);

        // Remove the protocol fee from the output amount
        outputValue -= protocolFee;

        // If we got all the way here, no math error happened
        error = Error.OK;
    }
}
