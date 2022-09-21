// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {BeaconAmmV1Pair} from "./BeaconAmmV1Pair.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";
import {IBeaconAmmV1RoyaltyManager} from "./IBeaconAmmV1RoyaltyManager.sol";
import {BeaconAmmV1Router} from "./BeaconAmmV1Router.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";

/**
    @title An NFT/Token pair where the token is an ERC20
    @author boredGenius and 0xmons
 */
abstract contract BeaconAmmV1PairERC20 is BeaconAmmV1Pair {
    using SafeTransferLib for ERC20;

    uint256 internal constant IMMUTABLE_PARAMS_LENGTH = 81;

    /**
        @notice Returns the ERC20 token associated with the pair
        @dev See BeaconAmmV1PairCloner for an explanation on how this works
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

    /// @inheritdoc BeaconAmmV1Pair
    function _pullTokenInputAndPayFees(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        IBeaconAmmV1PairFactory _factory,
        uint256 protocolFee,
        uint256 royaltyFee
    ) internal override {
        require(msg.value == 0, "ERC20 pair");

        ERC20 _token = token();
        address _assetRecipient = getAssetRecipient();

        if (isRouter) {
            // Verify if router is allowed
            BeaconAmmV1Router router = BeaconAmmV1Router(payable(msg.sender));

            // Locally scoped to avoid stack too deep
            {
                (bool routerAllowed, ) = _factory.routerStatus(router);
                require(routerAllowed, "Not router");
            }

            // Take royalty fee if exist
            // Locally scoped to avoid stack too deep
            {
                if (royaltyFee > 0) {
                    // no need to check manager is address(0) since royalty fee cannot be > 0 if so
                    address royaltyFeeRecipient = factory().royaltyManager().getFeeRecipient(address(nft()));
                    router.pairTransferERC20From(
                        _token,
                        routerCaller,
                        royaltyFeeRecipient,
                        royaltyFee,
                        pairVariant()
                    );
                    // Reduce royalty from input amount
                    inputAmount -= royaltyFee;
                }
            }

            // Cache state
            uint256 beforeBalance = _token.balanceOf(_assetRecipient);
            router.pairTransferERC20From(
                _token,
                routerCaller,
                _assetRecipient,
                inputAmount - protocolFee,
                pairVariant()
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
                pairVariant()
            );

            // Note: no check for factory balance's because router is assumed to be set by factory owner
            // so there is no incentive to *not* pay protocol fee
        } else {
            // Take royalty fee (if it exists)
            if (royaltyFee > 0) {
                // no need to check manager is address(0) since royalty fee cannot be > 0 if so
                address royaltyFeeRecipient = factory().royaltyManager().getFeeRecipient(address(nft()));
                _token.safeTransferFrom(
                    msg.sender,
                    royaltyFeeRecipient,
                    royaltyFee
                );
                // Reduce royalty from input amount
                inputAmount -= royaltyFee;
            }

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

    /// @inheritdoc BeaconAmmV1Pair
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Do nothing since we transferred the exact input amount
    }

    /// @inheritdoc BeaconAmmV1Pair
    function _payFeesFromPair(
        IBeaconAmmV1PairFactory _factory,
        uint256 protocolFee,
        uint256 royaltyFee
    ) internal override {
        ERC20 _token = token();

        // Take protocol fee (if it exists)
        if (protocolFee > 0) {

            // Round down to the actual token balance if there are numerical stability issues with the bonding curve calculations
            uint256 pairTokenBalance = _token.balanceOf(address(this));
            if (protocolFee > pairTokenBalance) {
                protocolFee = pairTokenBalance;
            }
            if (protocolFee > 0) {
                _token.safeTransfer(address(_factory), protocolFee);
            }
        }

        // Pay royalty fee (if it exists)
        if (royaltyFee > 0) {
            // Round down to the actual token balance if there are numerical stability issues with the bonding curve calculations
            uint256 pairTokenBalance = _token.balanceOf(address(this));
            if (royaltyFee > pairTokenBalance) {
                royaltyFee = pairTokenBalance;
            }
            if (royaltyFee > 0) {
                // no need to check manager is address(0) since royalty fee cannot be > 0 if so
                IBeaconAmmV1RoyaltyManager royaltyManager = factory().royaltyManager();
                _token.safeTransfer(royaltyManager.getFeeRecipient(address(nft())), royaltyFee);
            }
        }
    }

    /// @inheritdoc BeaconAmmV1Pair
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send tokens to caller
        if (outputAmount > 0) {
            token().safeTransfer(tokenRecipient, outputAmount);
        }
    }

    /// @inheritdoc BeaconAmmV1Pair
    // @dev see BeaconAmmV1PairCloner for params length calculation
    function _immutableParamsLength() internal pure override returns (uint256) {
        return IMMUTABLE_PARAMS_LENGTH;
    }

    /// @inheritdoc BeaconAmmV1Pair
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
}
