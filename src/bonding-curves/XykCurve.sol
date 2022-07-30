// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ICurve} from "./ICurve.sol";
import {CurveErrorCodes} from "./CurveErrorCodes.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {LSSVMPair} from "../LSSVMPair.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPairCloner} from "../lib/LSSVMPairCloner.sol";
import {LSSVMPairERC20} from "../LSSVMPairERC20.sol";

/*
    @author 0xacedia
    @notice Bonding curve logic for an x*y=k curve.
*/
contract XykCurve is ICurve, CurveErrorCodes {
    address factory;

    address public immutable enumerableETHTemplate;
    address public immutable missingEnumerableETHTemplate;

    constructor(
        address _factory,
        address _enumerableETHTemplate,
        address _missingEnumerableETHTemplate
    ) {
        factory = _factory;
        enumerableETHTemplate = _enumerableETHTemplate;
        missingEnumerableETHTemplate = _missingEnumerableETHTemplate;
    }

    /**
        @dev See {ICurve-validateDelta}
     */
    function validateDelta(uint128 delta)
        external
        pure
        override
        returns (bool)
    {
        // delta should never be set
        return delta == 0;
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
        if (numItems == 0) {
            return (Error.INVALID_NUMITEMS, 0, 0, 0, 0);
        }

        // get the pair's nft and eth/erc20 balance
        IERC721 nft = IERC721(LSSVMPair(msg.sender).nft());
        uint256 nftBalance = nft.balanceOf(msg.sender);
        uint256 tokenBalance = isETHPair(msg.sender)
            ? msg.sender.balance
            : LSSVMPairERC20(msg.sender).token().balanceOf(msg.sender);

        // calculate the amount to send in
        inputValue = (numItems * tokenBalance) / (nftBalance - numItems);

        // add the fees to the amount to send in
        protocolFee = (inputValue * protocolFeeMultiplier) / 1e18;
        uint256 fee = (inputValue * feeMultiplier) / 1e18;
        inputValue += fee + protocolFee;

        // possible overflow here
        newSpotPrice = uint128(
            (inputValue + tokenBalance) / (nftBalance - numItems)
        );

        // If we got all the way here, no math error happened
        error = Error.OK;
    }

    function isETHPair(address query) public view returns (bool) {
        return
            LSSVMPairCloner.isETHPairClone(
                factory,
                enumerableETHTemplate,
                query
            ) ||
            LSSVMPairCloner.isETHPairClone(
                factory,
                missingEnumerableETHTemplate,
                query
            );
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
        // If we got all the way here, no math error happened
        error = Error.OK;
    }
}
