// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/*
    @author 0xmons and boredGenius
    @notice Bonding curve logic for a gradual dutch auction curve, where the price decreases exponentially over time if nobody buys NFTs
    and increases exponentially when someone buys NFTs
*/
contract GDACurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;
    using FixedPointMathLib for uint256;

    // minimum price to prevent numerical issues
    uint256 public constant MIN_PRICE = 1 gwei;

    /**
        @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint128 delta)
        external
        pure
        override
        returns (bool)
    {
        (uint256 alpha, , ) = _parseDelta(delta);
        return alpha > FixedPointMathLib.WAD;
    }

    /**
        @dev See {ICurve-validateSpotPrice}
     */
    function validateSpotPrice(uint128 newSpotPrice)
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
        uint128 spotPrice,
        uint128 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        view
        override
        returns (
            Error error,
            uint128 newSpotPrice,
            uint128 newDelta,
            uint256 inputValue,
            uint256 protocolFee
        )
    {
        // NOTE: we assume alpha is > 1, as checked by validateDelta()
        // We only calculate changes for buying 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        (uint256 alpha, , ) = _parseDelta(delta);

        uint256 alphaPowN = uint256(alpha).fpow(
            numItems,
            FixedPointMathLib.WAD
        );

        // For an exponential curve, the spot price is multiplied by alpha for each item bought
        {
            uint256 newSpotPrice_ = uint256(spotPrice).fmul(
                alphaPowN,
                FixedPointMathLib.WAD
            );
            if (newSpotPrice_ > type(uint128).max) {
                return (Error.SPOT_PRICE_OVERFLOW, 0, 0, 0, 0);
            }
            newSpotPrice = uint128(newSpotPrice_);
        }

        uint256 decayFactor;
        {
            (, uint256 lambda, uint256 startTime) = _parseDelta(delta);
            decayFactor = ((block.timestamp - startTime) * lambda).exp();
        }

        // Spot price is assumed to be the instant sell price. To avoid arbitraging LPs, we adjust the buy price upwards.
        // If spot price for buy and sell were the same, then someone could buy 1 NFT and then sell for immediate profit.
        // EX: Let S be spot price. Then buying 1 NFT costs S ETH, now new spot price is (S * alpha).
        // The same person could then sell for (S * alpha) ETH, netting them alpha ETH profit.
        // If spot price for buy and sell differ by alpha, then buying costs (S * alpha) ETH.
        // The new spot price would become (S * alpha), so selling would also yield (S * alpha) ETH.
        /// uint256 buySpotPrice = uint256(spotPrice).fmul(
        ///     alpha,
        ///     FixedPointMathLib.WAD
        /// );
        // If the user buys n items, then the total cost is equal to:
        // buySpotPrice + (alpha * buySpotPrice) + (alpha^2 * buySpotPrice) + ... (alpha^(numItems - 1) * buySpotPrice)
        // This is equal to buySpotPrice * (alpha^n - 1) / (alpha - 1)
        // We then divide the value by e^(lambda * timeElapsed) to factor in the exponential decay
        inputValue = uint256(spotPrice).fmul(alpha, FixedPointMathLib.WAD);
        inputValue = inputValue.fmul(
            (alphaPowN - FixedPointMathLib.WAD),
            alpha - FixedPointMathLib.WAD
        );
        inputValue = inputValue.fdiv(decayFactor, FixedPointMathLib.WAD);

        // Account for the protocol fee, a flat percentage of the buy amount
        protocolFee = inputValue.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );

        // Account for the trade fee, only for Trade pools
        inputValue += inputValue.fmul(feeMultiplier, FixedPointMathLib.WAD);

        // Add the protocol fee to the required input amount
        inputValue += protocolFee;

        // Keep delta the same
        newDelta = delta;

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
        uint128 spotPrice,
        uint128 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        view
        override
        returns (
            Error error,
            uint128 newSpotPrice,
            uint128 newDelta,
            uint256 outputValue,
            uint256 protocolFee
        )
    {
        // NOTE: we assume delta is > 1, as checked by validateDelta()

        // We only calculate changes for buying 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        uint256 invAlpha;
        {
            (uint256 alpha, , ) = _parseDelta(delta);
            invAlpha = FixedPointMathLib.WAD.fdiv(alpha, FixedPointMathLib.WAD);
        }
        uint256 invAlphaPowN = invAlpha.fpow(numItems, FixedPointMathLib.WAD);

        // For an exponential curve, the spot price is divided by alpha for each item sold
        // safe to convert newSpotPrice directly into uint128 since we know newSpotPrice <= spotPrice
        // and spotPrice <= type(uint128).max
        newSpotPrice = uint128(
            uint256(spotPrice).fmul(invAlphaPowN, FixedPointMathLib.WAD)
        );
        if (newSpotPrice < MIN_PRICE) {
            newSpotPrice = uint128(MIN_PRICE);
        }

        uint256 boostFactor;
        {
            (, uint256 lambda, uint256 startTime) = _parseDelta(delta);
            boostFactor = ((block.timestamp - startTime) * lambda).exp();
        }

        // If the user sells n items, then the total revenue is equal to:
        // spotPrice + ((1 / alpha) * spotPrice) + ((1 / alpha)^2 * spotPrice) + ... ((1 / alpha)^(numItems - 1) * spotPrice)
        // This is equal to spotPrice * (1 - (1 / alpha^n)) / (1 - (1 / alpha))
        // We then multiply this by the exponential boost factor e^(lambda * timeElapsed)
        outputValue = uint256(spotPrice).fmul(
            (FixedPointMathLib.WAD - invAlphaPowN),
            (FixedPointMathLib.WAD - invAlpha)
        );
        outputValue = outputValue.fmul(boostFactor, FixedPointMathLib.WAD);

        // Account for the protocol fee, a flat percentage of the sell amount
        protocolFee = outputValue.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );

        // Account for the trade fee, only for Trade pools
        outputValue -= outputValue.fmul(feeMultiplier, FixedPointMathLib.WAD);

        // Remove the protocol fee from the output amount
        outputValue -= protocolFee;

        // Keep delta the same
        newDelta = delta;

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    function _parseDelta(uint128 delta)
        internal
        pure
        returns (
            uint40 alpha,
            uint40 lambda,
            uint48 startTime
        )
    {
        // the highest 40 bits are alpha
        // which is the same as delta in ExponentialCurve
        alpha = uint40(delta >> 88);

        // the lower 40 bits are lambda
        // lambda determines the exponential decay over time
        // see https://www.paradigm.xyz/2022/04/gda
        lambda = uint40(delta >> 48);

        // the lowest 48 bits are the start timestamp
        // this works because solidity cuts off higher bits when converting
        // from a larger type to a smaller type
        // see https://docs.soliditylang.org/en/latest/types.html#explicit-conversions
        startTime = uint48(delta);
    }
}
