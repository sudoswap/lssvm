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
    @notice Bonding curve logic for an x*y=k curve.
*/
contract XykCurve is ICurve, CurveErrorCodes {
    /**
        @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint128 delta)
        external
        pure
        override
        returns (bool)
    {
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
        // all values should be valid
        return true;
    }

    /**
        @dev See {ICurve-getBuyInfo}. For ETH pairs, the previous eth balance is stored in `delta`.
        This is so that we don't include the msg.value when calculating the swap price.
        For example:
            * call swap with msg.value
            * input is calculated with pair's ETH balance and NFT balance
        There is a cyclical depdency on msg.value. So it needs to be tracked seperatelyxs.
        This is not an issue for ERC20 tokens because ERC20 tokens are transferred in only AFTER getBuyInfo is called.
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's nft and eth/erc20 balance
        LSSVMPair pair = LSSVMPair(msg.sender);
        IERC721 nft = IERC721(pair.nft());
        uint256 nftBalance = nft.balanceOf(msg.sender);
        uint256 tokenBalance = isETHPair(pair)
            ? delta // previous eth balance (avoids including msg.value)
            : LSSVMPairERC20(msg.sender).token().balanceOf(msg.sender);

        // calculate the amount to send in
        inputValue = (numItems * tokenBalance) / (nftBalance - numItems);

        // add the fees to the amount to send in
        protocolFee = (inputValue * protocolFeeMultiplier) / 1e18;
        uint256 fee = (inputValue * feeMultiplier) / 1e18;
        inputValue += fee + protocolFee;

        // possible overflow here because of uint256 -> uint128 casting
        newSpotPrice = uint128(
            (inputValue + tokenBalance) / (nftBalance - numItems)
        );

        // save the current eth balance
        newDelta = uint128(msg.sender.balance);

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    function isETHPair(LSSVMPair pair) public pure returns (bool) {
        ILSSVMPairFactoryLike.PairVariant variant = pair.pairVariant();

        return
            variant ==
            ILSSVMPairFactoryLike.PairVariant.MISSING_ENUMERABLE_ETH ||
            variant == ILSSVMPairFactoryLike.PairVariant.ENUMERABLE_ETH;
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's nft and eth/erc20 balance
        LSSVMPair pair = LSSVMPair(msg.sender);
        IERC721 nft = IERC721(pair.nft());
        uint256 nftBalance = nft.balanceOf(msg.sender);
        uint256 tokenBalance = isETHPair(pair)
            ? msg.sender.balance
            : LSSVMPairERC20(msg.sender).token().balanceOf(msg.sender);

        // calculate the amount to send out
        outputValue = (numItems * tokenBalance) / (nftBalance + numItems);

        // subtract fees from amount to send out
        protocolFee = (outputValue * protocolFeeMultiplier) / 1e18;
        uint256 fee = (outputValue * feeMultiplier) / 1e18;
        outputValue -= fee + protocolFee;

        newSpotPrice = uint128(
            (tokenBalance - outputValue) / (nftBalance + numItems)
        );

        // save the current eth balance
        newDelta = uint128(msg.sender.balance);

        // If we got all the way here, no math error happened
        error = Error.OK;
    }
}
