// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";
import {LSSVMPairFactory} from "./LSSVMPairFactory.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";

contract LSSVMPairMissingEnumerable is LSSVMPair {
    event Foo(uint256);

    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address payable;

    // ID tracking
    EnumerableSet.UintSet private idSet;

    /**
     * External functions
     */

    /**
        @notice Sends ETH to the pair in exchange for any `numNFTs` NFTs
        @dev To compute the amount of ETH to send, call bondingCurve.getBuyInfo.
        This swap function is meant for users who are ID agnostic
        @param numNFTs The number of NFTs to purchase
        @param nftRecipient The recipient of the NFTs
        @return inputAmount The amount of ETH used for purchase
     */
    function swapETHForAnyNFTs(uint256 numNFTs, address nftRecipient)
        external
        payable
        override
        nonReentrant
        returns (uint256 inputAmount)
    {
        // Store storage variables locally for cheaper lookup
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;
        PoolType _poolType = poolType;

        // Input validation
        require(
            _poolType == PoolType.NFT || _poolType == PoolType.TRADE,
            "Wrong Pool type"
        );
        require(
            (numNFTs > 0) && (numNFTs <= _nft.balanceOf(address(this))),
            "Ask for > 0 and <= balanceOf NFTs"
        );

        // Call bonding curve for pricing information
        uint256 protocolFee;
        {
            CurveErrorCodes.Error error;
            uint256 newSpotPrice;
            (error, newSpotPrice, inputAmount, protocolFee) = bondingCurve
                .getBuyInfo(
                    spotPrice,
                    delta,
                    numNFTs,
                    fee,
                    _factory.protocolFeeMultiplier()
                );
            require(error == CurveErrorCodes.Error.OK, "Bonding curve error");

            // Update spot price
            spotPrice = newSpotPrice;
            emit SpotPriceUpdated(newSpotPrice);
        }

        // Pricing-dependent validation
        require(msg.value >= inputAmount, "Sent too little ETH");

        // Send NFTs to caller
        // We're missing enumerable, so we also update the pair's own ID set
        for (uint256 i = 0; i < numNFTs; i++) {
            uint256 nftId = idSet.at(0);
            _nft.safeTransferFrom(address(this), nftRecipient, nftId);
            idSet.remove(nftId);
        }

        // Give excess ETH back to caller
        if (msg.value > inputAmount) {
            payable(msg.sender).sendValue(msg.value - inputAmount);
        }

        // Take protoocol fee
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }

        emit SwapWithAnyNFTs(inputAmount, numNFTs, false);
    }

    /**
        @notice Sends ETH to the pair in exchange for a specific set of NFTs
        @dev To compute the amount of ETH to send, call bondingCurve.getBuyInfo
        This swap is meant for users who want specific IDs. Also higher chance of
        reverting if some of the specified IDs leave the pool before the swap goes through.
        @param nftIds The list of IDs of the NFTs to purchase
        @param nftRecipient The recipient of the NFTs
        @return inputAmount The amount of ETH used for purchase
     */
    function swapETHForSpecificNFTs(
        uint256[] calldata nftIds,
        address nftRecipient
    ) external payable override nonReentrant returns (uint256 inputAmount) {
        // Store storage variables locally for cheaper lookup
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;

        {
            // Input validation
            PoolType _poolType = poolType;
            require(
                _poolType == PoolType.NFT || _poolType == PoolType.TRADE,
                "Wrong Pool type"
            );
            require(
                (nftIds.length > 0) &&
                    (nftIds.length <= _nft.balanceOf(address(this))),
                "Must ask for > 0 and < balanceOf NFTs"
            );
        }

        // Call bonding curve for pricing information
        uint256 protocolFee;
        {
            uint256 newSpotPrice;
            CurveErrorCodes.Error error;
            (error, newSpotPrice, inputAmount, protocolFee) = bondingCurve
                .getBuyInfo(
                    spotPrice,
                    delta,
                    nftIds.length,
                    fee,
                    _factory.protocolFeeMultiplier()
                );
            require(error == CurveErrorCodes.Error.OK, "Bonding curve error");

            // Update spot price
            spotPrice = newSpotPrice;
            emit SpotPriceUpdated(newSpotPrice);
        }

        // Pricing-dependent validation
        require(msg.value >= inputAmount, "Sent too little ETH");

        // Send NFTs to caller
        // If missing enumerable, update pool's own ID set
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(address(this), nftRecipient, nftIds[i]);
            // Remove from id set
            idSet.remove(nftIds[i]);
        }

        // Give excess ETH back to caller
        if (msg.value > inputAmount) {
            payable(msg.sender).sendValue(msg.value - inputAmount);
        }

        // Take protocol fee
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }

        emit SwapWithSpecificNFTs(inputAmount, nftIds, false);
    }

    /**
        @notice Sends a set of NFTs to the pair in exchange for ETH
        @dev To compute the amount of ETH to that will be received, call bondingCurve.getSellInfo
        @param nftIds The list of IDs of the NFTs to sell to the pair
        @param minExpectedETHOutput The minimum acceptable ETH received by the sender. If the actual
        amount is less than this value, the transaction will be reverted.
        @param ethRecipient The recipient of the ETH output
        @return outputAmount The amount of ETH received
     */
    function swapNFTsForETH(
        uint256[] calldata nftIds,
        uint256 minExpectedETHOutput,
        address payable ethRecipient
    ) external override nonReentrant returns (uint256 outputAmount) {
        // Store storage variables locally for cheaper lookup
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;

        // Input validation
        {
            PoolType _poolType = poolType;
            require(
                _poolType == PoolType.ETH || _poolType == PoolType.TRADE,
                "Wrong Pool type"
            );
        }

        // Call bonding curve for pricing information
        uint256 protocolFee;
        {
            uint256 newSpotPrice;
            CurveErrorCodes.Error error;
            (error, newSpotPrice, outputAmount, protocolFee) = bondingCurve
                .getSellInfo(
                    spotPrice,
                    delta,
                    nftIds.length,
                    fee,
                    _factory.protocolFeeMultiplier()
                );
            require(error == CurveErrorCodes.Error.OK, "Bonding curve error");

            // Update spot price
            spotPrice = newSpotPrice;
            emit SpotPriceUpdated(newSpotPrice);
        }

        // Pricing-dependent validation
        require(outputAmount >= minExpectedETHOutput, "Out too little ETH");

        // Take in NFTs from caller
        // Because we're missing enumerable, update pool's own ID set
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(msg.sender, address(this), nftIds[i]);
            idSet.add(nftIds[i]);
        }

        // Send ETH to caller
        if (outputAmount > 0) {
            ethRecipient.sendValue(outputAmount);
        }

        // Take protocol fee
        if (protocolFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the above calculations
            uint256 pairETHBalance = address(this).balance;
            if (protocolFee > pairETHBalance) {
                protocolFee = pairETHBalance;
            }
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }

        emit SwapWithSpecificNFTs(outputAmount, nftIds, true);
    }

    /**
       @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() external view override returns (uint256[] memory) {
        uint256 numNFTs = nft.balanceOf(address(this));
        uint256[] memory ids = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; i++) {
            ids[i] = idSet.at(i);
        }
        return ids;
    }

    /**
        @dev Callback when safeTransfering an ERC721 in, we add ID to the idSet
        if it's the same collection used by pool (and doesn't auto-track via enumerable)
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes memory b
    ) public virtual override returns (bytes4) {
        IERC721 _nft = nft;
        if (msg.sender == address(_nft)) {
            if (b.length == 1 && b[0] == NFT_TRANSFER_START) {
                // Use NFT for trade
                require(
                    factory.routerAllowed(LSSVMRouter(payable(operator))),
                    "Not router"
                );
                nftBalanceAtTransferStart = _nft.balanceOf(address(this));
            }
            // Add id to id set
            idSet.add(id);
        }

        return super.onERC721Received(operator, from, id, b);
    }

    /**
      @dev This is only for withdrawing the pair's NFT collection
     */
    function withdrawNFT(uint256[] calldata nftIds)
        external
        onlyOwner
        onlyUnlocked
    {
        IERC721 _nft = nft;
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(address(this), msg.sender, nftIds[i]);
            idSet.remove(nftIds[i]);
        }
    }

    function withdrawERC721(address a, uint256[] calldata nftIds)
        external
        override
        onlyOwner
        onlyUnlocked
    {
        require(a != address(nft), "Call withdrawNFT");
        for (uint256 i = 0; i < nftIds.length; i++) {
            IERC721(a).safeTransferFrom(address(this), msg.sender, nftIds[i]);
        }
    }
}
