// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";

/**
    @title An NFT/Token pair where the token is an ERC20
    @author boredGenius and 0xmons
 */
abstract contract LSSVMPairERC20 is LSSVMPair {
    using SafeTransferLib for ERC20;

    /**
        @notice Returns the ERC20 token associated with the pair
        @dev See LSSVMPairCloner for an explanation on how this works
     */
    function token() public pure returns (ERC20 _token) {
        uint256 paramsLength = _immutableParamsLength();
        assembly {
            _token := shr(
                0x60,
                calldataload(add(sub(calldatasize(), paramsLength), 61))
            )
        }
    }

    /**
        @notice Verifies and takes the correct amount of tokens needed for a swap
        @param inputAmount The amount of tokens to be sent in
        @param isRouter Whether or not the caller is LSSVMRouter
        @param routerCaller If called from LSSVMRouter, store the original caller
        @param _factory The LSSVMPairFactory which stores LSSVMRouter allowlist info
     */
    function _validateTokenInput(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        LSSVMPairFactoryLike _factory
    ) internal override {
        require(msg.value == 0, "ERC20 pair");

        ERC20 _token = token();
        address _assetRecipient = getAssetRecipient();

        if (isRouter) {
            // Verify if router is allowed
            LSSVMRouter router = LSSVMRouter(payable(msg.sender));
            (bool routerAllowed, ) = _factory.routerStatus(router);
            require(routerAllowed, "Not router");

            // Call router to transfer tokens from user
            uint256 beforeBalance = _token.balanceOf(_assetRecipient);

            router.pairTransferERC20From(
                _token,
                routerCaller,
                _assetRecipient,
                inputAmount,
                pairVariant()
            );

            // Verify token transfer (protect pair against malicious router)
            require(
                _token.balanceOf(_assetRecipient) - beforeBalance ==
                    inputAmount,
                "ERC20 not transferred in"
            );
        } else {
            // Transfer tokens directly
            _token.safeTransferFrom(msg.sender, _assetRecipient, inputAmount);
        }
    }

    /**
        @notice Sends excess tokens back to the caller
     */
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Do nothing since we transferred the exact input amount
    }

    /**
        @notice Sends protocol fee (if it exists) back to the LSSVMPairFactory
     */
    function _payProtocolFee(LSSVMPairFactoryLike _factory, uint256 protocolFee)
        internal
        override
    {
        // Take protocol fee (if it exists)
        if (protocolFee > 0) {
            ERC20 _token = token();

            // Round down to the actual token balance if there are numerical stability issues with the bonding curve calculations
            uint256 pairTokenBalance = _token.balanceOf(address(this));
            if (protocolFee > pairTokenBalance) {
                protocolFee = pairTokenBalance;
            }
            _token.safeTransfer(address(_factory), protocolFee);
        }
    }

    /**
        @notice Sends tokens to a recipient
        @param tokenRecipient The address receiving the tokens
        @param outputAmount The amount of tokens to send
     */
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send tokens to caller
        if (outputAmount > 0) {
            token().safeTransfer(tokenRecipient, outputAmount);
        }
    }

    /**
        @dev Used internally to grab pair parameters from calldata, see LSSVMPairCloner for technical details
     */
    function _immutableParamsLength() internal pure override returns (uint256) {
        return 81;
    }

    /**
        @notice Withdraws ERC20 tokens from the pair to the owner. 
        @dev Only callable by the owner.
        @param a The address of the token to transfer
        @param amount The amount of tokens to send to the owner
     */
    function withdrawERC20(address a, uint256 amount)
        external
        override
        onlyOwner
    {
        ERC20(a).safeTransfer(msg.sender, amount);

        if (a == address(token())) {
            // emit event since it is the pair token
            emit TokenWithdrawn(amount);
        }
    }
}
