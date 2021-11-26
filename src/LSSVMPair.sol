// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";
import {LSSVMPairFactory} from "./LSSVMPairFactory.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";

abstract contract LSSVMPair is OwnableUpgradeable, ERC721Holder, ReentrancyGuard {

    using Address for address payable;

    enum PoolType {
        ETH,
        NFT,
        TRADE
    }

    uint256 internal constant MAX_FEE = 9e17; // 90%, must <= 1 - MAX_PROTOCOL_FEE
    bytes1 internal constant NFT_TRANSFER_START = 0x11;

    // Factory which stores several global values (e.g. protocol fee)
    LSSVMPairFactory public factory;

    // Temporarily used during LSSVMRouter::_swapNFTsForETH to store the number of NFTs transferred
    // directly to the pair. Should be 0 outside of the execution of routerSwapAnyNFTsForETH.
    uint256 internal nftBalanceAtTransferStart;

    // Collection address
    IERC721 public nft;

    // Pool pricing parameters
    ICurve public bondingCurve;
    PoolType public poolType;
    uint256 public spotPrice;
    uint256 public delta;

    // Fee is only relevant for TRADE pools
    uint256 public fee;

    // Pool locking check
    modifier onlyUnlocked() {
        require(block.timestamp >= unlockTime);
        _;
    }
    // When pool is unlocked (defaults to 0)
    uint256 public unlockTime;

    // Events
    event SwapWithAnyNFTs(
        uint256 ethAmount,
        uint256 numNFTs,
        bool nftsIntoPool
    );
    event SwapWithSpecificNFTs(
        uint256 ethAmount,
        uint256[] nftIds,
        bool nftsIntoPool
    );
    event SpotPriceUpdated(uint256 newSpotPrice);
    event ETHDeposited(uint256 amount);
    event ETHWithdrawn(uint256 amount);
    event DeltaUpdated(uint256 newDelta);
    event FeeUpdated(uint256 newFee);
    event PoolLocked(uint256 unlockTime);

    // Only called once by factory to initialize
    function initialize(
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPairFactory _factory,
        PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice
    ) external payable initializer {
        if ((_poolType == PoolType.ETH) || (_poolType == PoolType.NFT)) {
            require(_fee == 0, "Only Trade Pools can have nonzero fee");
        }
        if (_poolType == PoolType.TRADE) {
            require(_fee < MAX_FEE, "Trade fee must be less than 100%");
        }
        require(_bondingCurve.validateDelta(_delta), "Invalid delta for curve");
        factory = _factory;
        nft = _nft;
        bondingCurve = _bondingCurve;
        poolType = _poolType;
        delta = _delta;
        fee = _fee;
        spotPrice = _spotPrice;
        __Ownable_init();
    }

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
        virtual
        external
        payable
        returns (uint256 inputAmount);

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
    ) virtual external payable returns (uint256 inputAmount);

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
    ) virtual external returns (uint256 outputAmount);

    /**
        @notice Sells NFTs to the pair in exchange for ETH. Only callable by the LSSVMRouter.
        @dev To compute the amount of ETH to that will be received, call bondingCurve.getSellInfo
        @param ethRecipient The recipient of the ETH output
        @return outputAmount The amount of ETH received
     */
    function routerSwapNFTsForETH(address payable ethRecipient)
        external
        nonReentrant
        returns (uint256 outputAmount)
    {
        // Store storage variables locally for cheaper lookup
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;
        uint256 _nftBalanceAtTransferStart = nftBalanceAtTransferStart;
        delete nftBalanceAtTransferStart;

        // Input validation
        {
            PoolType _poolType = poolType;
            require(
                _poolType == PoolType.ETH || _poolType == PoolType.TRADE,
                "Wrong Pool type"
            );
        }
        require(_nftBalanceAtTransferStart != 0, "Not in router swap context");

        // Call bonding curve for pricing information
        uint256 protocolFee;
        uint256 numNFTs = _nft.balanceOf(address(this)) -
            _nftBalanceAtTransferStart +
            1;
        {
            uint256 newSpotPrice;
            CurveErrorCodes.Error error;
            (error, newSpotPrice, outputAmount, protocolFee) = bondingCurve
                .getSellInfo(
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

        // Send ETH to caller
        if (outputAmount > 0) {
            ethRecipient.sendValue(outputAmount);
        }

        // Take protocol fee
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }

        emit SwapWithAnyNFTs(outputAmount, numNFTs, true);
    }

    /**
       @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() virtual external view returns (uint256[] memory);

    /**
     * Owner functions
     */

    /**
        @notice Withdraws all ETH owned by the pair to the owner address.
        Only callable by the owner.
     */
    function withdrawAllETH() external onlyOwner onlyUnlocked nonReentrant{
        withdrawETH(address(this).balance);
    }

    /**
        @notice Withdraws a specified amount of ETH owned by the pair to the owner address.
        Only callable by the owner.
        @param amount The amount of ETH to send to the owner. If the pair's balance is less than
        this value, the transaction will be reverted.
     */
    function withdrawETH(uint256 amount) public onlyOwner onlyUnlocked {
        payable(owner()).sendValue(amount);
        emit ETHWithdrawn(amount);
    }

    /**
        @notice Rescues a specified set of NFTs owned by the pair to the owner address.
        @dev If the NFT is the pair's collection, we also remove it from the id tracking.
        @param a The address of the NFT to transfer
        @param nftIds The list of IDs of the NFTs to send to the owner
     */
    function withdrawERC721(address a, uint256[] calldata nftIds) virtual external;

    /**
        @notice Rescues ERC20 tokens from the pair to the owner. Only callable by the owner.
        @param a The address of the token to transfer
        @param amount The amount of tokens to send to the owner
     */
    function withdrawERC20(address a, uint256 amount)
        external
        onlyOwner
        onlyUnlocked
    {
        IERC20(a).transferFrom(address(this), msg.sender, amount);
    }

    /**
        @notice Rescues ERC1155 tokens from the pair to the owner. Only callable by the owner.
        @param a The address of the token to transfer
        @param ids The list of token IDs to send to the owner
        @param amounts The list of amounts of tokens to send to the owner
        @param data The raw data that the token might use in transfers
     */
    function withdrawERC1155(
        address a,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyOwner onlyUnlocked {
        IERC1155(a).safeBatchTransferFrom(
            address(this),
            msg.sender,
            ids,
            amounts,
            data
        );
    }

    /**
        @notice Updates the selling spot price. Only callable by the owner.
        @param newSpotPrice The new selling spot price value, in ETH
     */
    function changeSpotPrice(uint256 newSpotPrice)
        external
        onlyOwner
        onlyUnlocked
    {
        spotPrice = newSpotPrice;
        emit SpotPriceUpdated(newSpotPrice);
    }

    /**
        @notice Updates the delta parameter. Only callable by the owner.
        @param newDelta The new delta parameter
     */
    function changeDelta(uint256 newDelta) external onlyOwner onlyUnlocked {
        require(
            bondingCurve.validateDelta(newDelta),
            "Invalid delta for curve"
        );
        delta = newDelta;
        emit DeltaUpdated(newDelta);
    }

    /**
        @notice Updates the fee taken by the LP. Only callable by the owner.
        Only callable if the pool is a Trade pool. Reverts if the fee is >=
        MAX_FEE.
        @param newFee The new LP fee percentage, 18 decimals
     */
    function changeFee(uint256 newFee) external onlyOwner onlyUnlocked {
        require(poolType == PoolType.TRADE, "Only for Trade pools");
        require(newFee < MAX_FEE, "Trade fee must be less than 90%");
        fee = newFee;
        emit FeeUpdated(newFee);
    }

    /**
        @notice Allows the pair to make arbitrary external calls to contracts
        whitelisted by the protocol. Only callable by the owner.
        @param target The contract to call
        @param data The calldata
     */
    function call(address payable target, bytes calldata data)
        external
        onlyOwner
        onlyUnlocked
    {
        require(factory.callAllowed(target), "Target must be whitelisted");
        (bool result, ) = target.call{value: 0}(data);
        require(result, "Call failed");
    }

    /**
        @notice Locks owner controls until a later point in time. 
        @dev Intended to be used similar to locking LP tokens so users know
        the ETH/NFTs in the pool will remain at least until newUnlockTime
        @param newUnlockTime  The time when owner controls are reinstated
     */
    function lockPool(uint256 newUnlockTime) external onlyOwner onlyUnlocked {
        unlockTime = newUnlockTime;
        emit PoolLocked(newUnlockTime);
    }

    /**
     * Utility functions (not to be called directly, but also not internal)
     */

    /**
        @dev All ETH transfers into the pair are accepted. This is the main method
        for the owner to top up the pair's ETH reserves.
     */
    receive() external payable {
        emit ETHDeposited(msg.value);
    }

    /**
        @dev Used as read function to query the bonding curve for buy pricing info
     */
    function getBuyNFTQuote(uint256 numNFTs) external view returns (
        CurveErrorCodes.Error error,
        uint256 newSpotPrice,
        uint256 outputAmount,
        uint256 protocolFee
    ) {
        (error, newSpotPrice, outputAmount, protocolFee) = bondingCurve
            .getBuyInfo(
                spotPrice,
                delta,
                numNFTs,
                fee,
                factory.protocolFeeMultiplier()
            );
    }

    /**
        @dev Used as read function to query the bonding curve for sell pricing info
     */
    function getSellNFTQuote(uint256 numNFTs) external view returns (
        CurveErrorCodes.Error error,
        uint256 newSpotPrice,
        uint256 outputAmount,
        uint256 protocolFee
    ) {
        (error, newSpotPrice, outputAmount, protocolFee) = bondingCurve
            .getSellInfo(
                spotPrice,
                delta,
                numNFTs,
                fee,
                factory.protocolFeeMultiplier()
            );
    }
}
