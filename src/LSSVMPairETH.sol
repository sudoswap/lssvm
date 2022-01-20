// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";

/**
    @title An NFT/Token pair where the token is ETH
    @author boredGenius and 0xmons
 */
abstract contract LSSVMPairETH is LSSVMPair {
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    /**
        @notice Verifies and the correct amount of ETH needed for a swap is sent
        @param inputAmount The amount of ETH to be sent
     */
    function _validateTokenInput(
        uint256 inputAmount,
        bool, /*isRouter*/
        address, /*routerCaller*/
        LSSVMPairFactoryLike /*_factory*/
    ) internal override {
        require(msg.value >= inputAmount, "Sent too little ETH");

        // Transfer inputAmount ETH to assetRecipient if it's been set
        address payable _assetRecipient = getAssetRecipient();
        if (_assetRecipient != address(this)) {
            _assetRecipient.safeTransferETH(inputAmount);
        }
    }

    /**
        @notice Sends excess tokens back to the caller
        @dev We send ETH back to the caller even when called from LSSVMRouter because we do an aggregate slippage check for certain bulk swaps. (Instead of sending directly back to the router caller) 
        Excess ETH sent for one swap can then be used to help pay for the next swap.
     */
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Give excess ETH back to caller
        if (msg.value > inputAmount) {
            payable(msg.sender).safeTransferETH(msg.value - inputAmount);
        }
    }

    /**
        @notice Sends protocol fee (if it exists) back to the LSSVMPairFactory
     */
    function _payProtocolFee(LSSVMPairFactoryLike _factory, uint256 protocolFee)
        internal
        override
    {
        // Take protocol fee
        if (protocolFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the bonding curve calculations
            uint256 pairETHBalance = address(this).balance;
            if (protocolFee > pairETHBalance) {
                protocolFee = pairETHBalance;
            }
            payable(address(_factory)).safeTransferETH(protocolFee);
        }
    }

    /**
        @notice Sends ETH to a recipient
        @param tokenRecipient The address receiving the ETH
        @param outputAmount The amount of ETH to send
     */
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send ETH to caller
        if (outputAmount > 0) {
            tokenRecipient.safeTransferETH(outputAmount);
        }
    }

    /**
        @dev Used internally to grab pair parameters from calldata, see LSSVMPairCloner for technical details
     */
    function _immutableParamsLength() internal pure override returns (uint256) {
        return 61;
    }

    /**
        @notice Withdraws all token owned by the pair to the owner address.
        @dev Only callable by the owner.
     */
    function withdrawAllETH() external onlyOwner nonReentrant {
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
        emit TokenWithdrawn(amount);
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
    }

    /**
        @dev All ETH transfers into the pair are accepted. This is the main method
        for the owner to top up the pair's token reserves.
     */
    receive() external payable {
        emit TokenDeposited(msg.value);
    }

    /**
        @dev All ETH transfers into the pair are accepted. This is the main method
        for the owner to top up the pair's token reserves.
     */
    fallback() external payable {
        emit TokenDeposited(msg.value);
    }
}
