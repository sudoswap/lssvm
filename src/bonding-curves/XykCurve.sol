// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {LSSVMPair} from "../LSSVMPair.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPairCloner} from "../lib/LSSVMPairCloner.sol";
import {LSSVMPairERC20} from "../LSSVMPairERC20.sol";
import {ILSSVMPairFactoryLike} from "../LSSVMPairFactory.sol";

/*
    @author 0xacedia
    @notice Bonding curve logic for an x*y=k curve using virtual reserves.
    @dev The virtual token reserve is stored in `spotPrice` and the virtual nft reserve is stored in `delta`.
*/
contract XykCurve is ICurve, CurveErrorCodes {
    using FixedPointMathLib for uint256;

    /**
        @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint128 delta)
        external
        pure
        override
        returns (bool)
    {
        // all values are valid
        return true;
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
        // all values are valid
        return true;
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
        pure
        override
        returns (
            Error error,
            uint128 newSpotPrice,
            uint128 newDelta,
            uint256 inputValue,
            uint256 protocolFee
        )
    {
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's virtual nft and eth/erc20 reserves
        uint256 tokenBalance = spotPrice;
        uint256 nftBalance = delta;

        // calculate the amount to send in
        inputValue = (numItems * tokenBalance) / (nftBalance - numItems);

        // add the fees to the amount to send in
        protocolFee = inputValue.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );
        uint256 fee = inputValue.fmul(feeMultiplier, FixedPointMathLib.WAD);
        inputValue += fee + protocolFee;

        // set the new virtual reserves
        newSpotPrice = uint128(spotPrice + inputValue - protocolFee); // token reserves
        newDelta = uint128(nftBalance - numItems); // nft reserves

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    /**
        @dev See {ICurve-getSellInfo}
     */
    function getSellInfo(
        uint128 spotPrice,
        uint128 delta,
        uint256 numItems,
        uint256 feeMultiplier,
        uint256 protocolFeeMultiplier
    )
        external
        pure
        override
        returns (
            Error error,
            uint128 newSpotPrice,
            uint128 newDelta,
            uint256 outputValue,
            uint256 protocolFee
        )
    {
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's virtual nft and eth/erc20 balance
        uint256 tokenBalance = spotPrice;
        uint256 nftBalance = delta;

        // calculate the amount to send out
        outputValue = (numItems * tokenBalance) / (nftBalance + numItems);

        // subtract fees from amount to send out
        protocolFee = outputValue.fmul(
            protocolFeeMultiplier,
            FixedPointMathLib.WAD
        );
        uint256 fee = outputValue.fmul(feeMultiplier, FixedPointMathLib.WAD);
        outputValue -= fee + protocolFee;

        // set the new virtual reserves
        newSpotPrice = uint128(spotPrice - (outputValue + protocolFee)); // token reserves
        newDelta = uint128(nftBalance + numItems); // nft reserves

        // If we got all the way here, no math error happened
        error = Error.OK;
    }
}
