// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "forge-std/Test.sol";

/**
 * @author 0xmons, boredGenius, 0xCygaar
 * @notice Bonding curve logic for a gradual dutch auction based on https://www.paradigm.xyz/2022/04/gda.
 * @dev Trade pools will result in unexpected behavior due to the time factor always increasing. Buying an NFT
 * and selling it back into the pool will result in a non-zero difference. Therefore it is recommended to only
 * use this curve for single-sided pools.
 */
contract GDACurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;

    uint256 internal constant _SCALE_FACTOR = 1e9;

    // minimum price to prevent numerical issues
    uint256 public constant MIN_PRICE = 1 gwei;

    /**
     * @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint128 delta) external pure override returns (bool) {
        (uint256 alpha,,) = _parseDelta(delta);
        return alpha > FixedPointMathLib.WAD;
    }

    /**
     * @dev See {ICurve-validateSpotPrice}
     */
    function validateSpotPrice(uint128 newSpotPrice) external pure override returns (bool) {
        return newSpotPrice >= MIN_PRICE;
    }

    /**
     * @dev See {ICurve-getBuyInfo}
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
        returns (Error error, uint128 newSpotPrice, uint128 newDelta, uint256 inputValue, uint256 protocolFee)
    {
        // NOTE: we assume alpha is > 1, as checked by validateDelta()
        // We only calculate changes for buying 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        uint256 spotPrice_ = uint256(spotPrice);
        (uint256 alpha,,) = _parseDelta(delta);
        uint256 alphaPowN = uint256(alpha).powu(numItems);

        // TODO: should we cap the time elapsed or decay factor?
        uint256 decayFactor;
        {
            (, uint256 lambda, uint256 prevTime) = _parseDelta(delta);
            decayFactor = ((block.timestamp - prevTime) * lambda).exp();
        }

        // The new spot price is multiplied by alpha^n and divided by the time decay so future
        // calculations do not need to track number of items sold or the initial time/price. This new spot price
        // implicitly stores the the initial price, total items sold so far, and time elapsed since the start.
        {
            uint256 newSpotPrice_ = spotPrice_.mul(alphaPowN);
            newSpotPrice_ = newSpotPrice_.div(decayFactor);
            if (newSpotPrice_ > type(uint128).max) {
                return (Error.SPOT_PRICE_OVERFLOW, 0, 0, 0, 0);
            }
            newSpotPrice = uint128(newSpotPrice_);
        }

        // If the user buys n items, then the total cost is equal to:
        // buySpotPrice + (alpha * buySpotPrice) + (alpha^2 * buySpotPrice) + ... (alpha^(numItems - 1) * buySpotPrice).
        // This is equal to buySpotPrice * (alpha^n - 1) / (alpha - 1).
        // We then divide the value by e^(lambda * timeElapsed) to factor in the exponential decay.
        {
            inputValue = spotPrice_.mul(alphaPowN - FixedPointMathLib.WAD);
            inputValue = inputValue.div(alpha - FixedPointMathLib.WAD);
            inputValue = inputValue.div(decayFactor);

            // Account for the protocol fee, a flat percentage of the buy amount
            protocolFee = inputValue.mul(protocolFeeMultiplier);

            // Account for the trade fee, only for Trade pools
            inputValue += inputValue.mul(feeMultiplier);

            // Add the protocol fee to the required input amount
            inputValue += protocolFee;
        }

        // Update delta with the current timestamp
        newDelta = _getNewDelta(delta);

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    /**
     * @dev See {ICurve-getSellInfo}
     *     If newSpotPrice is less than MIN_PRICE, newSpotPrice is set to MIN_PRICE instead.
     *     This is to prevent the spot price from ever becoming 0, which would decouple the price
     *     from the bonding curve (since 0 * delta is still 0)
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
        returns (Error error, uint128 newSpotPrice, uint128 newDelta, uint256 outputValue, uint256 protocolFee)
    {
        // We only calculate changes for buying 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        uint256 spotPrice_ = uint256(spotPrice);
        (uint256 alpha,,) = _parseDelta(delta);
        uint256 alphaPowN = uint256(alpha).powu(numItems);

        uint256 boostFactor;
        {
            (, uint256 lambda, uint256 startTime) = _parseDelta(delta);
            boostFactor = ((block.timestamp - startTime) * lambda).exp();
        }

        // The new spot price is multiplied by the time decay and divided by alpha^n so future
        // calculations do not need to track number of items sold or the initial time/price. This new spot price
        // implicitly stores the the initial price, total items sold so far, and time elapsed since the start.
        {
            uint256 newSpotPrice_ = spotPrice_.mul(boostFactor);
            newSpotPrice_ = newSpotPrice_.div(alphaPowN);
            if (newSpotPrice_ > type(uint128).max) {
                return (Error.SPOT_PRICE_OVERFLOW, 0, 0, 0, 0);
            }
            newSpotPrice = uint128(newSpotPrice_);
        }

        // The expected output at for an auction at index n is defined by the formula: p(t) = k * e^(lambda * t) / alpha^n
        // where k is the initial price, lambda is the decay constant, t is time elapsed, alpha is the scale factor, and
        // n is the number of items sold. The amount to receive for selling into a pool can thus be written as:
        // k * e^(lambda * t) / alpha^(m + q - 1) * (alpha^q - 1) / (alpha - 1) where m is the number of items purchased thus far
        // and q is the number of items to sell.
        // Our spot prices implicity embed the number of items already purchased and the previous time decay, so we just need to
        // do some simple adjustments to get the current e^(lambda * t) and alpha^(m + q - 1) values.
        outputValue = spotPrice_.mul(boostFactor).div(uint256(alpha).powu(numItems - 1));
        outputValue = outputValue.mul(alphaPowN - FixedPointMathLib.WAD);
        outputValue = outputValue.div(alpha - FixedPointMathLib.WAD);

        // Account for the protocol fee, a flat percentage of the sell amount
        protocolFee = outputValue.mul(protocolFeeMultiplier);

        // Account for the trade fee, only for Trade pools
        outputValue -= outputValue.mul(feeMultiplier);

        // Remove the protocol fee from the output amount
        outputValue -= protocolFee;

        // Update delta with the current timestamp
        newDelta = _getNewDelta(delta);

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    function _parseDelta(uint128 delta) internal pure returns (uint256 alpha, uint256 lambda, uint256 prevTime) {
        // the highest 40 bits are alpha
        // which is the same as delta in ExponentialCurve
        alpha = uint40(delta >> 88) * _SCALE_FACTOR;

        // the middle 40 bits are lambda
        // lambda determines the exponential decay over time
        // see https://www.paradigm.xyz/2022/04/gda
        lambda = uint40(delta >> 48) * _SCALE_FACTOR;

        // the lowest 48 bits are the start timestamp
        // this works because solidity cuts off higher bits when converting
        // from a larger type to a smaller type
        // see https://docs.soliditylang.org/en/latest/types.html#explicit-conversions
        prevTime = uint256(uint48(delta));
    }

    function _getNewDelta(uint128 delta) internal view returns (uint128) {
        // Clear lower 48 bits
        delta = (delta >> 48) << 48;
        // Set lower 48 bits to be the current timestamp
        return delta | uint48(block.timestamp);
    }
}
