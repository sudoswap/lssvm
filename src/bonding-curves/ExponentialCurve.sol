// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

/*
    @author 0xmons and boredGenius
    @notice Bonding curve logic for an exponential curve, where each buy/sell changes spot price by multiplying/dividing delta
*/
contract ExponentialCurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;

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
        return delta > PRBMathUD60x18.SCALE;
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
        if (spotPrice < MIN_PRICE) {
            spotPrice = MIN_PRICE;
        }
        
        uint256 deltaPowN = delta.powu(numItems);

        // For an exponential curve, the spot price is multiplied by delta for each item bought
        newSpotPrice = spotPrice.mul(deltaPowN);

        // Spot price is assumed to be the instant sell price. To avoid arbitraging LPs, we adjust the buy price upwards.
        // If spot price for buy and sell were the same, then someone could buy 1 NFT and then sell for immediate profit.
        // EX: Let S be spot price. Then buying 1 NFT costs S ETH, now new spot price is (S * delta).
        // The same person could then sell for (S * delta) ETH, netting them delta ETH profit.
        // If spot price for buy and sell differ by delta, then buying costs (S * delta) ETH.
        // The new spot price would become (S * delta), so selling would also yield (S * delta) ETH.
        uint256 buySpotPrice = spotPrice.mul(delta);

        // If the user buys n items, then the total cost is equal to:
        // buySpotPrice + (delta * buySpotPrice) + (delta^2 * buySpotPrice) + ... (delta^(numItems - 1) * buySpotPrice)
        // This is equal to buySpotPrice * (delta^n - 1) / (delta - 1)
        inputValue = buySpotPrice.mul(
            (deltaPowN - PRBMathUD60x18.SCALE).div(delta - PRBMathUD60x18.SCALE)
        );

        // Account for the protocol fee, a flat percentage of the buy amount
        protocolFee = inputValue.mul(protocolFeeMultiplier);

        // Account for the trade fee, only for Trade pools
        inputValue += inputValue.mul(feeMultiplier);

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
        if (spotPrice < MIN_PRICE) {
            spotPrice = MIN_PRICE;
        }

        uint256 invDelta = delta.inv();
        uint256 invDeltaPowN = invDelta.powu(numItems);

        // For an exponential curve, the spot price is divided by delta for each item sold
        newSpotPrice = spotPrice.mul(invDeltaPowN);
        if (newSpotPrice < MIN_PRICE) {
            newSpotPrice = MIN_PRICE;
        }

        // If the user sells n items, then the total revenue is equal to:
        // spotPrice + ((1 / delta) * spotPrice) + ((1 / delta)^2 * spotPrice) + ... ((1 / delta)^(numItems - 1) * spotPrice)
        // This is equal to spotPrice * (1 - (1 / delta^n)) / (1 - (1 / delta))
        outputValue = spotPrice.mul(
            (PRBMathUD60x18.SCALE - invDeltaPowN).div(
                PRBMathUD60x18.SCALE - invDelta
            )
        );

        // Account for the protocol fee, a flat percentage of the sell amount
        protocolFee = outputValue.mul(protocolFeeMultiplier);

        // Account for the trade fee, only for Trade pools
        outputValue -= outputValue.mul(feeMultiplier);

        // Remove the protocol fee from the output amount
        outputValue -= protocolFee;

        // If we got all the way here, no math error happened
        error = Error.OK;
    }
}
