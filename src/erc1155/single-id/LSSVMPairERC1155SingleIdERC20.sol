// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {LSSVMPairERC1155SingleId} from "./LSSVMPairERC1155SingleId.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";
import {ILSSVMPairERC1155FactoryLike} from "../ILSSVMPairERC1155FactoryLike.sol";

/**
    @title An ERC1155 pair where the token is an ERC20
    @author boredGenius and 0xmons
 */
contract LSSVMPairERC1155SingleIdERC20 is LSSVMPairERC1155SingleId {
    using SafeTransferLib for ERC20;

    uint256 internal constant IMMUTABLE_PARAMS_LENGTH = 81;

    /**
        Public functions
     */

    /// @inheritdoc LSSVMPairERC1155SingleId
    function pairVariant()
        public
        pure
        virtual
        override
        returns (ILSSVMPairERC1155FactoryLike.PairVariant)
    {
        return ILSSVMPairERC1155FactoryLike.PairVariant.SINGLE_ID_ERC20;
    }

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

    /// @inheritdoc LSSVMPairERC1155SingleId
    function withdrawERC20(ERC20 a, uint256 amount)
        external
        override
        onlyOwner
    {
        a.safeTransfer(msg.sender, amount);

        if (a == token()) {
            // emit event since it is the pair token
            emit TokenWithdrawal(amount);
        }
    }

    /**
        Internal functions
     */

    /// @inheritdoc LSSVMPairERC1155SingleId
    function _pullTokenInputAndPayProtocolFee(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        ILSSVMPairERC1155FactoryLike _factory,
        uint256 protocolFee
    ) internal override {
        require(msg.value == 0, "ERC20 pair");

        ERC20 _token = token();
        address _assetRecipient = getAssetRecipient();

        if (isRouter) {
            // Verify if router is allowed
            LSSVMRouter router = LSSVMRouter(payable(msg.sender));

            // Locally scoped to avoid stack too deep
            {
                (bool routerAllowed, ) = _factory.routerStatus(router);
                require(routerAllowed, "Not router");
            }

            // Cache state and then call router to transfer tokens from user
            uint256 beforeBalance = _token.balanceOf(_assetRecipient);
            router.pairTransferERC20From(
                _token,
                routerCaller,
                _assetRecipient,
                inputAmount - protocolFee,
                uint8(pairVariant())
            );

            // Verify token transfer (protect pair against malicious router)
            require(
                _token.balanceOf(_assetRecipient) - beforeBalance ==
                    inputAmount - protocolFee,
                "ERC20 not transferred in"
            );

            router.pairTransferERC20From(
                _token,
                routerCaller,
                address(_factory),
                protocolFee,
                uint8(pairVariant())
            );

            // Note: no check for factory balance's because router is assumed to be set by factory owner
            // so there is no incentive to *not* pay protocol fee
        } else {
            // Transfer tokens directly
            _token.safeTransferFrom(
                msg.sender,
                _assetRecipient,
                inputAmount - protocolFee
            );

            // Take protocol fee (if it exists)
            if (protocolFee > 0) {
                _token.safeTransferFrom(
                    msg.sender,
                    address(_factory),
                    protocolFee
                );
            }
        }
    }

    /// @inheritdoc LSSVMPairERC1155SingleId
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Do nothing since we transferred the exact input amount
    }

    /// @inheritdoc LSSVMPairERC1155SingleId
    function _payProtocolFeeFromPair(
        ILSSVMPairERC1155FactoryLike _factory,
        uint256 protocolFee
    ) internal override {
        // Take protocol fee (if it exists)
        if (protocolFee > 0) {
            ERC20 _token = token();

            // Round down to the actual token balance if there are numerical stability issues with the bonding curve calculations
            uint256 pairTokenBalance = _token.balanceOf(address(this));
            if (protocolFee > pairTokenBalance) {
                protocolFee = pairTokenBalance;
            }
            if (protocolFee > 0) {
                _token.safeTransfer(address(_factory), protocolFee);
            }
        }
    }

    /// @inheritdoc LSSVMPairERC1155SingleId
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send tokens to caller
        if (outputAmount > 0) {
            token().safeTransfer(tokenRecipient, outputAmount);
        }
    }

    /// @inheritdoc LSSVMPairERC1155SingleId
    // @dev see LSSVMPairCloner for params length calculation
    function _immutableParamsLength() internal pure override returns (uint256) {
        return IMMUTABLE_PARAMS_LENGTH;
    }
}
