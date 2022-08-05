// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// @dev Solmate's ERC20 is used instead of OZ's ERC20 so we can use safeTransferLib for cheaper safeTransfers for
// ETH and ERC20 tokens
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {LSSVMRouter} from "../LSSVMRouter.sol";
import {ICurve} from "../bonding-curves/ICurve.sol";
import {LSSVMPairFactory} from "../LSSVMPairFactory.sol";
import {LSSVMPairERC1155Cloner} from "./lib/LSSVMPairERC1155Cloner.sol";
import {LSSVMPairERC1155ManyId} from "./many-id/LSSVMPairERC1155ManyId.sol";
import {LSSVMPairERC1155SingleId} from "./single-id/LSSVMPairERC1155SingleId.sol";
import {ILSSVMPairERC1155FactoryLike} from "./ILSSVMPairERC1155FactoryLike.sol";
import {LSSVMPairERC1155ManyIdETH} from "./many-id/LSSVMPairERC1155ManyIdETH.sol";
import {LSSVMPairERC1155ManyIdERC20} from "./many-id/LSSVMPairERC1155ManyIdERC20.sol";
import {LSSVMPairERC1155SingleIdETH} from "./single-id/LSSVMPairERC1155SingleIdETH.sol";
import {LSSVMPairERC1155SingleIdERC20} from "./single-id/LSSVMPairERC1155SingleIdERC20.sol";

contract LSSVMPairERC1155Factory is Ownable, ILSSVMPairERC1155FactoryLike {
    using LSSVMPairERC1155Cloner for address;
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

    LSSVMPairFactory public immutable baseFactory;
    LSSVMPairERC1155ManyIdETH public immutable manyIdETHTemplate;
    LSSVMPairERC1155ManyIdERC20 public immutable manyIdERC20Template;
    LSSVMPairERC1155SingleIdETH public immutable singleIdETHTemplate;
    LSSVMPairERC1155SingleIdERC20 public immutable singleIdERC20Template;

    event NewPair(address poolAddress);
    event TokenDeposit(address poolAddress);
    event NFTDeposit(address poolAddress);

    constructor(
        LSSVMPairFactory _baseFactory,
        LSSVMPairERC1155ManyIdETH _manyIdETHTemplate,
        LSSVMPairERC1155ManyIdERC20 _manyIdERC20Template,
        LSSVMPairERC1155SingleIdETH _singleIdETHTemplate,
        LSSVMPairERC1155SingleIdERC20 _singleIdERC20Template
    ) {
        baseFactory = _baseFactory;
        manyIdETHTemplate = _manyIdETHTemplate;
        manyIdERC20Template = _manyIdERC20Template;
        singleIdETHTemplate = _singleIdETHTemplate;
        singleIdERC20Template = _singleIdERC20Template;
    }

    /**
     * External functions
     */

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _assetRecipient The address that will receive the assets traders give during trades.
                              If set to address(0), assets will be sent to the pool address.
                              Not available to TRADE pools. 
        @param _poolType TOKEN, NFT, or TRADE
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
        @return pair The new pair
     */
    function createPairManyIdETH(
        IERC1155 _nft,
        ICurve _bondingCurve,
        address payable _assetRecipient,
        LSSVMPairERC1155ManyIdETH.PoolType _poolType,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external payable returns (LSSVMPairERC1155ManyIdETH pair) {
        require(
            bondingCurveAllowed(_bondingCurve),
            "Bonding curve not whitelisted"
        );

        pair = LSSVMPairERC1155ManyIdETH(
            payable(
                address(manyIdETHTemplate).cloneManyIdETHPair(
                    this,
                    _bondingCurve,
                    _nft,
                    uint8(_poolType)
                )
            )
        );

        _initializePairManyIdETH(
            pair,
            _nft,
            _assetRecipient,
            _delta,
            _fee,
            _spotPrice,
            _initialNFTIDs
        );
        emit NewPair(address(pair));
    }

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _assetRecipient The address that will receive the assets traders give during trades.
                                If set to address(0), assets will be sent to the pool address.
                                Not available to TRADE pools.
        @param _poolType TOKEN, NFT, or TRADE
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price, in ETH
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
        @param _initialTokenBalance The initial token balance sent from the sender to the new pair
        @return pair The new pair
     */
    struct CreateManyIdERC20PairParams {
        ERC20 token;
        IERC1155 nft;
        ICurve bondingCurve;
        address payable assetRecipient;
        LSSVMPairERC1155ManyIdERC20.PoolType poolType;
        uint128 delta;
        uint96 fee;
        uint128 spotPrice;
        uint256[] initialNFTIDs;
        uint256 initialTokenBalance;
    }

    function createPairManyIdERC20(CreateManyIdERC20PairParams calldata params)
        external
        returns (LSSVMPairERC1155ManyIdERC20 pair)
    {
        require(
            bondingCurveAllowed(params.bondingCurve),
            "Bonding curve not whitelisted"
        );

        pair = LSSVMPairERC1155ManyIdERC20(
            payable(
                address(manyIdERC20Template).cloneManyIdERC20Pair(
                    this,
                    params.bondingCurve,
                    params.nft,
                    uint8(params.poolType),
                    params.token
                )
            )
        );

        _initializePairManyIdERC20(
            pair,
            params.token,
            params.nft,
            params.assetRecipient,
            params.delta,
            params.fee,
            params.spotPrice,
            params.initialNFTIDs,
            params.initialTokenBalance
        );
        emit NewPair(address(pair));
    }

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _assetRecipient The address that will receive the assets traders give during trades.
                              If set to address(0), assets will be sent to the pool address.
                              Not available to TRADE pools. 
        @param _poolType TOKEN, NFT, or TRADE
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price
        @param _nftId The ID of the NFT to trade
        @param _initialNFTBalance The amount of NFTs to transfer from the sender to the pair
        @return pair The new pair
     */
    function createPairSingleIdETH(
        IERC1155 _nft,
        ICurve _bondingCurve,
        address payable _assetRecipient,
        LSSVMPairERC1155ManyIdETH.PoolType _poolType,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256 _nftId,
        uint256 _initialNFTBalance
    ) external payable returns (LSSVMPairERC1155SingleIdETH pair) {
        require(
            bondingCurveAllowed(_bondingCurve),
            "Bonding curve not whitelisted"
        );

        pair = LSSVMPairERC1155SingleIdETH(
            payable(
                address(singleIdETHTemplate).cloneSingleIdETHPair(
                    this,
                    _bondingCurve,
                    _nft,
                    uint8(_poolType),
                    _nftId
                )
            )
        );

        _initializePairSingleIdETH(
            pair,
            _nft,
            _assetRecipient,
            _delta,
            _fee,
            _spotPrice,
            _nftId,
            _initialNFTBalance
        );
        emit NewPair(address(pair));
    }

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _assetRecipient The address that will receive the assets traders give during trades.
                                If set to address(0), assets will be sent to the pool address.
                                Not available to TRADE pools.
        @param _poolType TOKEN, NFT, or TRADE
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price, in ETH
        @param _nftId The ID of the NFT to trade
        @param _initialNFTBalance The amount of NFTs to transfer from the sender to the pair
        @param _initialTokenBalance The initial token balance sent from the sender to the new pair
        @return pair The new pair
     */
    struct CreateSingleIdERC20PairParams {
        ERC20 token;
        IERC1155 nft;
        ICurve bondingCurve;
        address payable assetRecipient;
        LSSVMPairERC1155ManyIdERC20.PoolType poolType;
        uint128 delta;
        uint96 fee;
        uint128 spotPrice;
        uint256 nftId;
        uint256 initialNFTBalance;
        uint256 initialTokenBalance;
    }

    function createPairSingleIdERC20(
        CreateSingleIdERC20PairParams calldata params
    ) external returns (LSSVMPairERC1155SingleIdERC20 pair) {
        require(
            bondingCurveAllowed(params.bondingCurve),
            "Bonding curve not whitelisted"
        );

        pair = LSSVMPairERC1155SingleIdERC20(
            payable(
                address(singleIdERC20Template).cloneSingleIdERC20Pair(
                    this,
                    params.bondingCurve,
                    params.nft,
                    uint8(params.poolType),
                    params.nftId,
                    params.token
                )
            )
        );

        _initializePairSingleIdERC20(
            pair,
            params.token,
            params.nft,
            params.assetRecipient,
            params.delta,
            params.fee,
            params.spotPrice,
            params.nftId,
            params.initialNFTBalance,
            params.initialTokenBalance
        );
        emit NewPair(address(pair));
    }

    /**
        @notice Checks if an address is a pair. Uses the fact that the pairs are EIP-1167 minimal proxies.
        @param potentialPair The address to check
        @param variant The pair variant (NFT is enumerable or not, pair uses ETH or ERC20)
        @return True if the address is the specified pair variant, false otherwise
     */
    function isPair(address potentialPair, PairVariant variant)
        public
        view
        override
        returns (bool)
    {
        if (variant == PairVariant.SINGLE_ID_ETH) {
            return
                LSSVMPairERC1155Cloner.isSingleIdETHPairClone(
                    address(this),
                    address(singleIdETHTemplate),
                    potentialPair
                );
        } else if (variant == PairVariant.MANY_ID_ETH) {
            return
                LSSVMPairERC1155Cloner.isManyIdETHPairClone(
                    address(this),
                    address(manyIdETHTemplate),
                    potentialPair
                );
        } else if (variant == PairVariant.SINGLE_ID_ERC20) {
            return
                LSSVMPairERC1155Cloner.isSingleIdERC20PairClone(
                    address(this),
                    address(singleIdERC20Template),
                    potentialPair
                );
        } else if (variant == PairVariant.MANY_ID_ERC20) {
            return
                LSSVMPairERC1155Cloner.isManyIdERC20PairClone(
                    address(this),
                    address(manyIdERC20Template),
                    potentialPair
                );
        } else {
            // invalid input
            return false;
        }
    }

    /**
        @notice Allows receiving ETH in order to receive protocol fees
     */
    receive() external payable {}

    /**
     * Passthrough functions
     */

    function protocolFeeRecipient()
        public
        view
        override
        returns (address payable)
    {
        return baseFactory.protocolFeeRecipient();
    }

    function protocolFeeMultiplier() external view override returns (uint256) {
        return baseFactory.protocolFeeMultiplier();
    }

    function bondingCurveAllowed(ICurve curve) public view returns (bool) {
        return baseFactory.bondingCurveAllowed(curve);
    }

    function callAllowed(address target) external view override returns (bool) {
        return baseFactory.callAllowed(target);
    }

    function routerStatus(LSSVMRouter router)
        external
        view
        override
        returns (bool allowed, bool wasEverAllowed)
    {
        return baseFactory.routerStatus(router);
    }

    /**
     * Admin functions
     */

    /**
        @notice Withdraws the ETH balance to the protocol fee recipient.
        Only callable by the owner.
     */
    function withdrawETHProtocolFees() external onlyOwner {
        protocolFeeRecipient().safeTransferETH(address(this).balance);
    }

    /**
        @notice Withdraws ERC20 tokens to the protocol fee recipient. Only callable by the owner.
        @param token The token to transfer
        @param amount The amount of tokens to transfer
     */
    function withdrawERC20ProtocolFees(ERC20 token, uint256 amount)
        external
        onlyOwner
    {
        token.safeTransfer(protocolFeeRecipient(), amount);
    }

    /**
     * Internal functions
     */

    function _initializePairManyIdETH(
        LSSVMPairERC1155ManyIdETH _pair,
        IERC1155 _nft,
        address payable _assetRecipient,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) internal {
        // initialize pair
        _pair.initialize(msg.sender, _assetRecipient, _delta, _fee, _spotPrice);

        // transfer initial ETH to pair
        payable(address(_pair)).safeTransferETH(msg.value);

        // transfer initial NFTs from sender to pair
        uint256 numNFTs = _initialNFTIDs.length;
        uint256[] memory amounts = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; ) {
            amounts[i] = 1;

            unchecked {
                ++i;
            }
        }
        _nft.safeBatchTransferFrom(
            msg.sender,
            address(_pair),
            _initialNFTIDs,
            amounts,
            bytes("")
        );
    }

    function _initializePairManyIdERC20(
        LSSVMPairERC1155ManyIdERC20 _pair,
        ERC20 _token,
        IERC1155 _nft,
        address payable _assetRecipient,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        uint256 _initialTokenBalance
    ) internal {
        // initialize pair
        _pair.initialize(msg.sender, _assetRecipient, _delta, _fee, _spotPrice);

        // transfer initial tokens to pair
        _token.safeTransferFrom(
            msg.sender,
            address(_pair),
            _initialTokenBalance
        );

        // transfer initial NFTs from sender to pair
        uint256 numNFTs = _initialNFTIDs.length;
        uint256[] memory amounts = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; ) {
            amounts[i] = 1;

            unchecked {
                ++i;
            }
        }
        _nft.safeBatchTransferFrom(
            msg.sender,
            address(_pair),
            _initialNFTIDs,
            amounts,
            bytes("")
        );
    }

    function _initializePairSingleIdETH(
        LSSVMPairERC1155SingleIdETH _pair,
        IERC1155 _nft,
        address payable _assetRecipient,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256 _nftId,
        uint256 _initialNFTBalance
    ) internal {
        // initialize pair
        _pair.initialize(msg.sender, _assetRecipient, _delta, _fee, _spotPrice);

        // transfer initial ETH to pair
        payable(address(_pair)).safeTransferETH(msg.value);

        // transfer initial NFTs from sender to pair
        _nft.safeTransferFrom(
            msg.sender,
            address(_pair),
            _nftId,
            _initialNFTBalance,
            bytes("")
        );
    }

    function _initializePairSingleIdERC20(
        LSSVMPairERC1155SingleIdERC20 _pair,
        ERC20 _token,
        IERC1155 _nft,
        address payable _assetRecipient,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256 _nftId,
        uint256 _initialNFTBalance,
        uint256 _initialTokenBalance
    ) internal {
        // initialize pair
        _pair.initialize(msg.sender, _assetRecipient, _delta, _fee, _spotPrice);

        // transfer initial tokens to pair
        _token.safeTransferFrom(
            msg.sender,
            address(_pair),
            _initialTokenBalance
        );

        // transfer initial NFTs from sender to pair
        _nft.safeTransferFrom(
            msg.sender,
            address(_pair),
            _nftId,
            _initialNFTBalance,
            bytes("")
        );
    }

    // TODO: is this still needed?
    /** 
      @dev Used to deposit NFTs into a pair after creation and emit an event for indexing (if recipient is indeed a pair)
    */
    function depositNFTs(
        IERC1155 _nft,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address recipient
    ) external {
        // transfer NFTs from caller to recipient
        _nft.safeBatchTransferFrom(
            msg.sender,
            recipient,
            ids,
            amounts,
            bytes("")
        );
        if (
            isPair(recipient, PairVariant.SINGLE_ID_ETH) ||
            isPair(recipient, PairVariant.MANY_ID_ETH) ||
            isPair(recipient, PairVariant.SINGLE_ID_ERC20) ||
            isPair(recipient, PairVariant.MANY_ID_ERC20)
        ) {
            emit NFTDeposit(recipient);
        }
    }

    /**
      @dev Used to deposit ERC20s into a pair after creation and emit an event for indexing (if recipient is indeed an ERC20 pair and the token matches)
     */
    function depositERC20(
        ERC20 token,
        address recipient,
        uint256 amount
    ) external {
        token.safeTransferFrom(msg.sender, recipient, amount);
        if (isPair(recipient, PairVariant.SINGLE_ID_ERC20)) {
            if (token == LSSVMPairERC1155SingleIdERC20(recipient).token()) {
                emit TokenDeposit(recipient);
            }
        } else if (isPair(recipient, PairVariant.MANY_ID_ERC20)) {
            if (token == LSSVMPairERC1155ManyIdERC20(recipient).token()) {
                emit TokenDeposit(recipient);
            }
        }
    }
}
