// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";

/*
@author 0xmons and boredGenius
@notice Bonding curve logic for a linear curve, where each buy/sell changes spot price by adding/substracting delta
*/
contract LinearCurve is ICurve, CurveErrorCodes {
    using PRBMathUD60x18 for uint256;

    /*
    @notice Checks if a given delta is valid for the linear bonding curve
    @dev All deltas are valid
    @param delta The delta value being checked
    @return valid Whether or not the delta value is valid
    */
    function validateDelta(
        uint256 /*delta*/
    ) external pure override returns (bool valid) {
        return true;
    }

    /*
    @notice When swapping ETH for NFTs, calculates exactly how much ETH to send, the new spot price, and the fee to take
    @dev See inline comments for calculation logic
    @param spotPrice The current spot price for 1 NFT, if it were to be sold
    @param delta The change in price for each successive NFT buy along the linear curve
    @param numItems The number of NFTs to be bought
    @param feeMultiplier The LP's fee multiplier (only for Trade pools)
    @param protocolFeeMultiplier The protocol fee multiplier
    @return error Any math calculation errors, only Error.OK means the returned values are valid
    @return newSpotPrice The updated spot price for 1 NFT
    @return inputValue The required amount of ETH to be sent
    @return protocolFee The amount of ETH from inputValue that goes to the protocol
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

        // For a linear curve, the spot price increases by delta for each item bought
        newSpotPrice = spotPrice + delta * numItems;

        // Spot price is assumed to be the instant sell price. To avoid arbitraging LPs, we adjust the buy price upwards.
        // If spot price for buy and sell were the same, then someone could buy 1 NFT and then sell for immediate profit.
        // EX: Let S be spot price. Then buying 1 NFT costs S ETH, now new spot price is (S+delta).
        // The same person could then sell for (S+delta) ETH, netting them delta ETH profit.
        // If spot price for buy and sell differ by delta, then buying costs (S+delta) ETH.
        // The new spot price would become (S+delta), so selling would also yield (S+delta) ETH.
        uint256 buySpotPrice = spotPrice + delta;

        // If we buy n items, then the total cost is equal to:
        // (buy spot price) + (buy spot price + 1*delta) + (buy spot price + 2*delta) + ... + (buy spot price + (n-1)*delta)
        // This is equal to n*(buy spot price) + (delta)*(n*(n-1))/2
        // because we have n instances of buy spot price, and then we sum up from delta to (n-1)*delta
        inputValue =
            numItems *
            buySpotPrice +
            (numItems * (numItems - 1) * delta) /
            2;

        // Account for the protocol fee, a flat percentage of the buy amount
        protocolFee = inputValue.mul(protocolFeeMultiplier);

        // Account for the trade fee, only for Trade pools
        inputValue += inputValue.mul(feeMultiplier);

        // Add the protocol fee to the required input amount
        inputValue += protocolFee;

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    /*
    @notice When swapping NFTs for ETH, calculates exactly how much ETH to send, the new spot price, and the fee to take
    @dev See inline comments for calculation logic
    @param spotPrice The current spot price for 1 NFT, if it were to be sold
    @param delta The change in price for each successive NFT sell along the linear curve
    @param numItems The number of NFTs to be sold
    @param feeMultiplier The LP's fee multiplier (only for Trade pools)
    @param protocolFeeMultiplier The protocol fee multiplier
    @return error Any math calculation errors, only Error.OK means the returned values are valid
    @return newSpotPrice The updated spot price for 1 NFT
    @return outputValue The required amount of ETH to be given to the seller
    @return protocolFee The amount of ETH from that goes to the protocol
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
        // We only calculate changes for selling 1 or more NFTs
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0);
        }

        // We first calculate the change in spot price after selling all of the items
        uint256 totalPriceDecrease = delta * numItems;

        // If the current spot price is less than the total amount that the spot price changes...
        if (spotPrice < totalPriceDecrease) {
            // Then we set the new spot price to be 0. (Spot price is never negative)
            newSpotPrice = 0;

            // We calculate how many items we can sell into the linear curve until the spot price reaches 0, rounding up
            // See below for how this is handled
            uint256 numItemsTillZeroPrice = spotPrice / delta + 1;

            // If we sell numItemsTillZeroPrice items, then the total sale amount is:
            // (spot price) + (spot price - 1*delta) + (spot price - 2*delta) + ... + (spot price - (numItemsTillZeroPrice-1)*delta)
            // This is equal to numItemsTillZeroPrice*spotPrice - (delta)*(numItemsTillZeroPrice*(numItemsTillZeroPrice-1))/2
            // To those worried about edge cases, notice that:
            // If spot price is less than delta, then we will only sell 1 item, so we only charge spot price as (delta)*(numItemsTillZeroPrice*(numItemsTillZeroPrice-1))/2 = 0
            // If spot price is greater than delta, then we will sell at least 2 items, so we charge spot price for each item. Then we subtract delta (cumulatively) for each item past the first.
            outputValue =
                numItemsTillZeroPrice *
                spotPrice -
                (numItemsTillZeroPrice * (numItemsTillZeroPrice - 1) * delta) /
                2;
            // Otherwise, the current spot price is greater than or equal to the total amount that the spot price changes
            // Thus we don't need to calculate the maximum number of items until we reach zero spot price
        } else {
            // The new spot price is just the change between spot price and the total price change
            newSpotPrice = spotPrice - totalPriceDecrease;

            // If we sell n items, then the total sale amount is:
            // (spot price) + (spot price - 1*delta) + (spot price - 2*delta) + ... + (spot price - (n-1)*delta)
            // This is equal to n*(spot price) - (delta)*(n*(n-1))/2
            outputValue =
                numItems *
                spotPrice -
                (numItems * (numItems - 1) * delta) /
                2;
        }

        // Account for the protocol fee, a flat percentage of the sell amount
        protocolFee = outputValue.mul(protocolFeeMultiplier);

        // Account for the trade fee, only for Trade pools
        outputValue -= outputValue.mul(feeMultiplier);

        // Subtract the protocol fee from the output amount to the seller
        outputValue -= protocolFee;

        // If we reached here, no math errors
        error = Error.OK;
    }
}
