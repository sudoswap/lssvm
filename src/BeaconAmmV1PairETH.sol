// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BeaconAmmV1Pair} from "./BeaconAmmV1Pair.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";
import {IBeaconAmmV1RoyaltyManager} from "./IBeaconAmmV1RoyaltyManager.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";

/**
    @title An NFT/Token pair where the token is ETH
    @author boredGenius and 0xmons
 */
abstract contract BeaconAmmV1PairETH is BeaconAmmV1Pair {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    uint256 internal constant IMMUTABLE_PARAMS_LENGTH = 61;

    /// @inheritdoc BeaconAmmV1Pair
    function _pullTokenInputAndPayFees(
        uint256 inputAmount,
        bool, /*isRouter*/
        address, /*routerCaller*/
        IBeaconAmmV1PairFactory _factory,
        uint256 protocolFee,
        uint256 royaltyFee
    ) internal override {
        require(msg.value >= inputAmount, "Sent too little ETH");

        // Transfer inputAmount ETH to assetRecipient if it's been set
        address payable _assetRecipient = getAssetRecipient();
        if (_assetRecipient != address(this)) {
            _assetRecipient.safeTransferETH(inputAmount - protocolFee - royaltyFee);
        }

        // Take protocol fee
        if (protocolFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the bonding curve calculations
            if (protocolFee > address(this).balance) {
                protocolFee = address(this).balance;
            }

            if (protocolFee > 0) {
                payable(address(_factory)).safeTransferETH(protocolFee);
            }
        }

        // Take protocol fee
        if (royaltyFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the bonding curve calculations
            if (royaltyFee > address(this).balance) {
                royaltyFee = address(this).balance;
            }
            if (royaltyFee > 0) {
                // no need to check manager is address(0) since royalty fee cannot be > 0 if so
                factory().royaltyManager().getFeeRecipient(address(nft())).safeTransferETH(royaltyFee);
            }
        }
    }

    /// @inheritdoc BeaconAmmV1Pair
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Give excess ETH back to caller
        if (msg.value > inputAmount) {
            payable(msg.sender).safeTransferETH(msg.value - inputAmount);
        }
    }

    /// @inheritdoc BeaconAmmV1Pair
    function _payFeesFromPair(
        IBeaconAmmV1PairFactory _factory,
        uint256 protocolFee,
        uint256 royaltyFee
    ) internal override {
        // Take protocol fee
        if (protocolFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the bonding curve calculations
            if (protocolFee > address(this).balance) {
                protocolFee = address(this).balance;
            }

            if (protocolFee > 0) {
                payable(address(_factory)).safeTransferETH(protocolFee);
            }
        }

        // Take protocol fee
        if (royaltyFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the bonding curve calculations
            if (royaltyFee > address(this).balance) {
                royaltyFee = address(this).balance;
            }
            if (royaltyFee > 0) {
                // no need to check manager is address(0) since royalty fee cannot be > 0 if so
                factory().royaltyManager().getFeeRecipient(address(nft())).safeTransferETH(royaltyFee);
            }
        }
    }

    /// @inheritdoc BeaconAmmV1Pair
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send ETH to caller
        if (outputAmount > 0) {
            tokenRecipient.safeTransferETH(outputAmount);
        }
    }

    /// @inheritdoc BeaconAmmV1Pair
    // @dev see BeaconAmmV1PairCloner for params length calculation
    function _immutableParamsLength() internal pure override returns (uint256) {
        return IMMUTABLE_PARAMS_LENGTH;
    }

    /**
        @notice Withdraws all token owned by the pair to the owner address.
        @dev Only callable by the owner.
     */
    function withdrawAllETH() external onlyOwner {
        withdrawETH(address(this).balance);
    }

    /**
        @notice Withdraws a specified amount of token owned by the pair to the owner address.
        @dev Only callable by the owner.
        @param amount The amount of token to send to the owner. If the pair's balance is less than
        this value, the transaction will be reverted.
     */
    function withdrawETH(uint256 amount) public onlyOwner {
        payable(owner()).safeTransferETH(amount);

        // emit event since ETH is the pair token
        emit TokenWithdrawal(amount);
    }

    /// @inheritdoc BeaconAmmV1Pair
    function withdrawERC20(ERC20 a, uint256 amount)
        external
        override
        onlyOwner
    {
        a.safeTransfer(msg.sender, amount);
    }

    /**
        @dev All ETH transfers into the pair are accepted. This is the main method
        for the owner to top up the pair's token reserves.
     */
    receive() external payable {
        emit TokenDeposit(msg.value);
    }

    /**
        @dev All ETH transfers into the pair are accepted. This is the main method
        for the owner to top up the pair's token reserves.
     */
    fallback() external payable {
        // Only allow calls without function selector
        require (msg.data.length == _immutableParamsLength());
        emit TokenDeposit(msg.value);
    }
}
