// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "forge-std/Test.sol";

/*
    @author 0xmons and boredGenius
    @notice Bonding curve logic for a gradual dutch auction curve, where the price decreases exponentially over time if nobody buys NFTs
    and increases exponentially when someone buys NFTs*/
contract GDACurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;
    using FixedPointMathLib for uint256;

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
        // calculations do not need to track number of items sold or T_0.
        {
            uint256 newSpotPrice_ = spotPrice_.mul(alphaPowN);
            newSpotPrice_ = newSpotPrice_.div(decayFactor);
            if (newSpotPrice_ > type(uint128).max) {
                return (Error.SPOT_PRICE_OVERFLOW, 0, 0, 0, 0);
            }
            newSpotPrice = uint128(newSpotPrice_);
        }

        // If the user buys n items, then the total cost is equal to:
        // buySpotPrice + (alpha * buySpotPrice) + (alpha^2 * buySpotPrice) + ... (alpha^(numItems - 1) * buySpotPrice)
        // This is equal to buySpotPrice * (alpha^n - 1) / (alpha - 1)
        // We then divide the value by e^(lambda * timeElapsed) to factor in the exponential decay
        // inputValue = uint256(spotPrice).fmul(alpha, FixedPointMathLib.WAD);
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
        // NOTE: we assume delta is > 1, as checked by validateDelta()

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

        {
            uint256 newSpotPrice_ = spotPrice_.mul(boostFactor);
            newSpotPrice_ = newSpotPrice_.div(alphaPowN);
            if (newSpotPrice_ > type(uint128).max) {
                return (Error.SPOT_PRICE_OVERFLOW, 0, 0, 0, 0);
            }
            newSpotPrice = uint128(newSpotPrice_);
        }

        // If the user sells n items, then the total revenue is equal to:
        // spotPrice + ((1 / alpha) * spotPrice) + ((1 / alpha)^2 * spotPrice) + ... ((1 / alpha)^(numItems - 1) * spotPrice)
        // This is equal to spotPrice * (1 - (1 / alpha^n)) / (1 - (1 / alpha))
        // We then multiply this by the exponential boost factor e^(lambda * timeElapsed)
        outputValue = spotPrice_.mul(FixedPointMathLib.WAD - FixedPointMathLib.WAD.div(alphaPowN));
        outputValue = outputValue.div(FixedPointMathLib.WAD - FixedPointMathLib.WAD.div(alpha));
        outputValue = outputValue.mul(boostFactor);

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
