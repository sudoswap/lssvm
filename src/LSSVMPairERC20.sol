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

abstract contract LSSVMPairERC20 is LSSVMPair {
    using SafeTransferLib for ERC20;

    ERC20 public token;

    // Only called once by factory to initialize
    function initialize(
        ERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPairFactoryLike _factory,
        address payable _assetRecipient,
        PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice
    ) external payable initializer {
        __LSSVMPair_init(
            _nft,
            _bondingCurve,
            _factory,
            _assetRecipient,
            _poolType,
            _delta,
            _fee,
            _spotPrice
        );
        token = ERC20(address(_token));
    }

    function _validateTokenInput(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        LSSVMPairFactoryLike _factory
    ) internal override {
        require(msg.value == 0, "ERC20 pair");

        ERC20 _token = token;
        address _assetRecipient = _getAssetRecipient();

        if (isRouter) {
            // Verify if router is allowed
            LSSVMRouter router = LSSVMRouter(payable(msg.sender));
            require(_factory.routerAllowed(router), "Not router");

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

    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Do nothing since we transferred the exact input amount
    }

    function _payProtocolFee(LSSVMPairFactoryLike _factory, uint256 protocolFee)
        internal
        override
    {
        // Take protocol fee
        if (protocolFee > 0) {
            ERC20 _token = token;

            // Round down to the actual token balance if there are numerical stability issues with the above calculations
            uint256 pairTokenBalance = _token.balanceOf(address(this));
            if (protocolFee > pairTokenBalance) {
                protocolFee = pairTokenBalance;
            }
            _token.safeTransfer(address(_factory), protocolFee);
        }
    }

    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send tokens to caller
        if (outputAmount > 0) {
            token.safeTransfer(tokenRecipient, outputAmount);
        }
    }

    /**
        @notice Withdraws ERC20 tokens from the pair to the owner. Only callable by the owner.
        @param a The address of the token to transfer
        @param amount The amount of tokens to send to the owner
     */
    function withdrawERC20(address a, uint256 amount)
        external
        override
        onlyOwner
        onlyUnlocked
    {
        ERC20(a).safeTransferFrom(address(this), msg.sender, amount);

        if (a == address(token)) {
            // emit event since it is the pair token
            emit TokenWithdrawn(amount);
        }
    }
}
