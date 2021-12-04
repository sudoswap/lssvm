// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";

abstract contract LSSVMPairERC20 is LSSVMPair {
    using Address for address payable;
    using SafeERC20 for IERC20;

    IERC20 public token;

    // Only called once by factory to initialize
    function initialize(
        IERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPairFactoryLike _factory,
        PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice
    ) external payable initializer {
        __LSSVMPair_init(
            _nft,
            _bondingCurve,
            _factory,
            _poolType,
            _delta,
            _fee,
            _spotPrice
        );
        token = _token;
    }

    function isETHPair() external pure override returns (bool) {
        return false;
    }

    function _validateTokenInput(uint256 inputAmount) internal override {
        require(msg.value == 0, "ERC20 pair");
        token.safeTransferFrom(msg.sender, address(this), inputAmount);
    }

    function _refundTokenToSender(uint256 inputAmount) internal override {
        // do nothing since we transferred the exact input amount
    }

    function _payProtocolFee(LSSVMPairFactoryLike _factory, uint256 protocolFee)
        internal
        override
    {
        // Take protocol fee
        if (protocolFee > 0) {
            IERC20 _token = token;

            // Round down to the actual token balance if there are numerical stability issues with the above calculations
            uint256 pairTokenBalance = _token.balanceOf(address(this));
            if (protocolFee > pairTokenBalance) {
                protocolFee = pairTokenBalance;
            }
            _token.safeTransfer(_factory.protocolFeeRecipient(), protocolFee);
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
        IERC20(a).transferFrom(address(this), msg.sender, amount);

        if (a == address(token)) {
            // emit event since it is the pair token
            emit TokenWithdrawn(amount);
        }
    }
}
