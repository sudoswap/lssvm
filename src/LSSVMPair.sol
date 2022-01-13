// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {Ownable} from "./lib/Ownable.sol";
import {Bytecode} from "./lib/Bytecode.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";

abstract contract LSSVMPair is Ownable, ReentrancyGuard {
    using Bytecode for address;

    enum PoolType {
        TOKEN,
        NFT,
        TRADE
    }

    uint256 internal constant MAX_FEE = 9e17; // 90%, must <= 1 - MAX_PROTOCOL_FEE
    bytes1 internal constant NFT_TRANSFER_START = 0x11;

    // Temporarily used during LSSVMRouter::_swapNFTsForToken to store the number of NFTs transferred
    // directly to the pair. Should be 0 outside of the execution of routerSwapAnyNFTsForToken.
    uint256 internal nftBalanceAtTransferStart;

    uint256 public spotPrice;
    uint256 public delta;

    // Fee is only relevant for TRADE pools
    uint256 public fee;

    // If set to 0, NFTs/tokens sent by traders during trades will be sent to the pair.
    // Otherwise, assets will be sent to the set address. Not available to TRADE pools.
    address payable public assetRecipient;

    // Events
    event SwapWithAnyNFTs(
        uint256 tokenAmount,
        uint256 numNFTs,
        bool nftsIntoPool
    );
    event SwapWithSpecificNFTs(
        uint256 tokenAmount,
        uint256[] nftIds,
        bool nftsIntoPool
    );
    event SpotPriceUpdated(uint256 newSpotPrice);
    event TokenDeposited(uint256 amount);
    event TokenWithdrawn(uint256 amount);
    event DeltaUpdated(uint256 newDelta);
    event FeeUpdated(uint256 newFee);

    function __LSSVMPair_init(
        address _owner,
        address payable _assetRecipient,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice
    ) internal {
        require(owner() == address(0), "Initialized");
        __Ownable_init(_owner);

        (, ICurve _bondingCurve, , PoolType _poolType) = _readImmutableParams();

        if ((_poolType == PoolType.TOKEN) || (_poolType == PoolType.NFT)) {
            require(_fee == 0, "Only Trade Pools can have nonzero fee");

            assetRecipient = _assetRecipient;
        }
        if (_poolType == PoolType.TRADE) {
            require(_fee < MAX_FEE, "Trade fee must be less than 100%");
            require(
                _assetRecipient == address(0),
                "Trade pools can't set asset recipient"
            );

            fee = _fee;
        }
        require(_bondingCurve.validateDelta(_delta), "Invalid delta for curve");
        require(
            _bondingCurve.validateSpotPrice(_spotPrice),
            "Invalid new spot price for curve"
        );

        delta = _delta;
        spotPrice = _spotPrice;
    }

    /**
     * External state-changing functions
     */

    /**
        @notice Sends token to the pair in exchange for any `numNFTs` NFTs
        @dev To compute the amount of token to send, call bondingCurve.getBuyInfo.
        This swap function is meant for users who are ID agnostic
        @param numNFTs The number of NFTs to purchase
        @param nftRecipient The recipient of the NFTs
        @param isRouter True if calling from LSSVMRouter, false otherwise. Not used for
        ETH pairs.
        @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this address. Not used for
        ETH pairs.
        @return inputAmount The amount of token used for purchase
     */
    function swapTokenForAnyNFTs(
        uint256 numNFTs,
        address nftRecipient,
        bool isRouter,
        address routerCaller
    ) external payable virtual returns (uint256 inputAmount) {
        (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            IERC721 _nft,
            PoolType _poolType
        ) = _readImmutableParams();

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
            (error, newSpotPrice, inputAmount, protocolFee) = _bondingCurve
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

        _validateTokenInput(
            inputAmount,
            isRouter,
            routerCaller,
            _factory,
            _poolType
        );

        _sendAnyNFTsToRecipient(_nft, nftRecipient, numNFTs);

        _refundTokenToSender(inputAmount);

        _payProtocolFee(_factory, protocolFee);

        emit SwapWithAnyNFTs(inputAmount, numNFTs, false);
    }

    /**
        @notice Sends token to the pair in exchange for a specific set of NFTs
        @dev To compute the amount of token to send, call bondingCurve.getBuyInfo
        This swap is meant for users who want specific IDs. Also higher chance of
        reverting if some of the specified IDs leave the pool before the swap goes through.
        @param nftIds The list of IDs of the NFTs to purchase
        @param nftRecipient The recipient of the NFTs
        @param isRouter True if calling from LSSVMRouter, false otherwise. Not used for
        ETH pairs.
        @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this address. Not used for
        ETH pairs.
        @return inputAmount The amount of token used for purchase
     */
    function swapTokenForSpecificNFTs(
        uint256[] calldata nftIds,
        address nftRecipient,
        bool isRouter,
        address routerCaller
    ) external payable virtual returns (uint256 inputAmount) {
        (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            IERC721 _nft,
            PoolType _poolType
        ) = _readImmutableParams();

        // Input validation
        require(
            _poolType == PoolType.NFT || _poolType == PoolType.TRADE,
            "Wrong Pool type"
        );
        require(
            (nftIds.length > 0) &&
                (nftIds.length <= _nft.balanceOf(address(this))),
            "Must ask for > 0 and < balanceOf NFTs"
        );

        // Call bonding curve for pricing information
        uint256 protocolFee;
        {
            CurveErrorCodes.Error error;
            (error, spotPrice, inputAmount, protocolFee) = _bondingCurve
                .getBuyInfo(
                    spotPrice,
                    delta,
                    nftIds.length,
                    fee,
                    _factory.protocolFeeMultiplier()
                );
            require(error == CurveErrorCodes.Error.OK, "Bonding curve error");

            emit SpotPriceUpdated(spotPrice);
        }

        _validateTokenInput(
            inputAmount,
            isRouter,
            routerCaller,
            _factory,
            _poolType
        );

        _sendSpecificNFTsToRecipient(_nft, nftRecipient, nftIds);

        _refundTokenToSender(inputAmount);

        _payProtocolFee(_factory, protocolFee);

        emit SwapWithSpecificNFTs(inputAmount, nftIds, false);
    }

    /**
        @notice Sends a set of NFTs to the pair in exchange for token
        @dev To compute the amount of token to that will be received, call bondingCurve.getSellInfo
        @param nftIds The list of IDs of the NFTs to sell to the pair
        @param minExpectedTokenOutput The minimum acceptable token received by the sender. If the actual
        amount is less than this value, the transaction will be reverted.
        @param tokenRecipient The recipient of the token output
        @return outputAmount The amount of token received
     */
    function swapNFTsForToken(
        //Red
        uint256[] calldata nftIds,
        uint256 minExpectedTokenOutput,
        address payable tokenRecipient
    ) external virtual returns (uint256 outputAmount) {
        (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            IERC721 _nft,
            PoolType _poolType
        ) = _readImmutableParams();

        // Input validation
        require(
            _poolType == PoolType.TOKEN || _poolType == PoolType.TRADE,
            "Wrong Pool type"
        );

        // Call bonding curve for pricing information
        uint256 protocolFee;
        {
            uint256 newSpotPrice;
            CurveErrorCodes.Error error;
            (error, newSpotPrice, outputAmount, protocolFee) = _bondingCurve
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
        require(
            outputAmount >= minExpectedTokenOutput,
            "Out too little tokens"
        );

        _takeNFTsFromSender(_nft, nftIds, _poolType);

        _sendTokenOutput(tokenRecipient, outputAmount);

        _payProtocolFee(_factory, protocolFee);

        emit SwapWithSpecificNFTs(outputAmount, nftIds, true);
    }

    /**
        @notice Sells NFTs to the pair in exchange for token. Only callable by the LSSVMRouter.
        @dev To compute the amount of token to that will be received, call bondingCurve.getSellInfo
        @param tokenRecipient The recipient of the token output
        @return outputAmount The amount of token received
     */
    function routerSwapNFTsForToken(address payable tokenRecipient)
        external
        virtual
        returns (uint256 outputAmount)
    {
        // Store storage variables locally for cheaper lookup
        (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            IERC721 _nft,
            PoolType _poolType
        ) = _readImmutableParams();
        uint256 _nftBalanceAtTransferStart = nftBalanceAtTransferStart;
        delete nftBalanceAtTransferStart;

        // Input validation
        {
            require(
                _poolType == PoolType.TOKEN || _poolType == PoolType.TRADE,
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
            (error, newSpotPrice, outputAmount, protocolFee) = _bondingCurve
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

        _sendTokenOutput(tokenRecipient, outputAmount);

        _payProtocolFee(_factory, protocolFee);

        emit SwapWithAnyNFTs(outputAmount, numNFTs, true);
    }

    /**
     * View functions
     */

    /**
        @dev Used as read function to query the bonding curve for buy pricing info
     */
    function getBuyNFTQuote(uint256 numNFTs)
        external
        view
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputAmount,
            uint256 protocolFee
        )
    {
        (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            ,

        ) = _readImmutableParams();
        (error, newSpotPrice, inputAmount, protocolFee) = _bondingCurve
            .getBuyInfo(
                spotPrice,
                delta,
                numNFTs,
                fee,
                _factory.protocolFeeMultiplier()
            );
    }

    /**
        @dev Used as read function to query the bonding curve for sell pricing info
     */
    function getSellNFTQuote(uint256 numNFTs)
        external
        view
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputAmount,
            uint256 protocolFee
        )
    {
        (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            ,

        ) = _readImmutableParams();
        (error, newSpotPrice, outputAmount, protocolFee) = _bondingCurve
            .getSellInfo(
                spotPrice,
                delta,
                numNFTs,
                fee,
                _factory.protocolFeeMultiplier()
            );
    }

    /**
        @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() external view virtual returns (uint256[] memory);

    /**
        @notice Returns the pair's variant (NFT is enumerable or not, pair uses ETH or ERC20)
     */
    function pairVariant()
        public
        pure
        virtual
        returns (LSSVMPairFactoryLike.PairVariant);

    function factory() public view returns (LSSVMPairFactoryLike _factory) {
        //Red
        (_factory, , , ) = _readImmutableParams();
    }

    function bondingCurve() public view returns (ICurve _bondingCurve) {
        (, _bondingCurve, , ) = _readImmutableParams();
    }

    function nft() public view returns (IERC721 _nft) {
        (, , _nft, ) = _readImmutableParams();
    }

    function poolType() public view returns (PoolType _poolType) {
        (, , , _poolType) = _readImmutableParams();
    }

    /**
     * Internal functions
     */

    function _validateTokenInput(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        LSSVMPairFactoryLike _factory,
        PoolType _poolType
    ) internal virtual;

    function _refundTokenToSender(uint256 inputAmount) internal virtual;

    function _payProtocolFee(LSSVMPairFactoryLike _factory, uint256 protocolFee)
        internal
        virtual;

    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal virtual;

    function _sendAnyNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256 numNFTs
    ) internal virtual;

    function _sendSpecificNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256[] calldata nftIds
    ) internal virtual;

    function _takeNFTsFromSender(
        IERC721 _nft,
        uint256[] calldata nftIds,
        PoolType _poolType
    ) internal virtual;

    function _getAssetRecipient(PoolType _poolType)
        internal
        view
        returns (address payable _assetRecipient)
    {
        // If it's a TRADE pool, we know the recipient is 0
        // So just return address(this)
        if (_poolType == PoolType.TRADE) {
            return payable(address(this));
        }

        // Otherwise, we return the recipient if it's been set
        // or replace it with address(this) if it's 0
        _assetRecipient = assetRecipient;
        if (_assetRecipient == address(0)) {
            // Tokens will be transferred to address(this)
            _assetRecipient = payable(address(this));
        }
    }

    function _readImmutableParams()
        internal
        view
        returns (
            LSSVMPairFactoryLike _factory,
            ICurve _bondingCurve,
            IERC721 _nft,
            PoolType _poolType
        )
    {
        bytes memory packedParams = address(this).codeAt(0x2d, 0x6a);
        assembly {
            _factory := shr(0x60, mload(add(packedParams, 0x20)))
            _bondingCurve := shr(0x60, mload(add(packedParams, 0x34)))
            _nft := shr(0x60, mload(add(packedParams, 0x48)))
            _poolType := shr(0xf8, mload(add(packedParams, 0x5c)))
        }
    }

    /**
     * Owner functions
     */

    /**
        @notice Rescues a specified set of NFTs owned by the pair to the owner address.
        @dev If the NFT is the pair's collection, we also remove it from the id tracking.
        @param a The address of the NFT to transfer
        @param nftIds The list of IDs of the NFTs to send to the owner
     */
    function withdrawERC721(address a, uint256[] calldata nftIds)
        external
        virtual;

    /**
        @notice Rescues ERC20 tokens from the pair to the owner. Only callable by the owner.
        @param a The address of the token to transfer
        @param amount The amount of tokens to send to the owner
     */
    function withdrawERC20(address a, uint256 amount) external virtual;

    /**
        @notice Rescues ERC1155 tokens from the pair to the owner. Only callable by the owner.
        @param a The address of the token to transfer
        @param ids The list of token IDs to send to the owner
        @param amounts The list of amounts of tokens to send to the owner
        @param data The raw data that the token might use in transfers
     */
    function withdrawERC1155(
        //Red
        address a,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyOwner {
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
        @param newSpotPrice The new selling spot price value, in Token
     */
    function changeSpotPrice(uint256 newSpotPrice) external onlyOwner {
        //Red
        ICurve _bondingCurve = bondingCurve();
        require(
            _bondingCurve.validateSpotPrice(newSpotPrice),
            "Invalid new spot price for curve"
        );
        spotPrice = newSpotPrice;
        emit SpotPriceUpdated(newSpotPrice);
    }

    /**
        @notice Updates the delta parameter. Only callable by the owner.
        @param newDelta The new delta parameter
     */
    function changeDelta(uint256 newDelta) external onlyOwner {
        //Red
        ICurve _bondingCurve = bondingCurve();
        require(
            _bondingCurve.validateDelta(newDelta),
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
    function changeFee(uint256 newFee) external onlyOwner {
        //Red
        PoolType _poolType = poolType();
        require(_poolType == PoolType.TRADE, "Only for Trade pools");
        require(newFee < MAX_FEE, "Trade fee must be less than 90%");
        fee = newFee;
        emit FeeUpdated(newFee);
    }

    /**
        @notice Changes the address that will receive assets received from
        trades. Only callable by the owner.
        @param newRecipient The new asset recipient
     */
    function changeAssetRecipient(
        address payable newRecipient //Red
    ) external onlyOwner {
        PoolType _poolType = poolType();
        require(_poolType != PoolType.TRADE, "Not for Trade pools");
        assetRecipient = newRecipient;
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
    {
        LSSVMPairFactoryLike _factory = factory();
        require(_factory.callAllowed(target), "Target must be whitelisted");
        (bool result, ) = target.call{value: 0}(data);
        require(result, "Call failed");
    }

    /**
        Black fucking magic shit

        Including these decreases the gas cost of the swap functions
        because they optimize the Solidity binary search for function
        signatures (somehow) (maybe)

        source: trust me bro
     */

    uint256 public unlockTime;

    function lockPool(uint256) external {}
}
