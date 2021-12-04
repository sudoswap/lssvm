// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMPairETH} from "./LSSVMPairETH.sol";
import {LSSVMPairERC20} from "./LSSVMPairERC20.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";

contract LSSVMPairFactory is Ownable, LSSVMPairFactoryLike {
    using Clones for address;
    using Address for address payable;

    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE =
        type(IERC721Enumerable).interfaceId;

    uint256 internal constant MAX_PROTOCOL_FEE = 1e17; // 10%, must <= 1 - MAX_FEE

    LSSVMPairETH public immutable enumerableETHTemplate;
    LSSVMPairETH public immutable missingEnumerableETHTemplate;
    LSSVMPairERC20 public immutable enumerableERC20Template;
    LSSVMPairERC20 public immutable missingEnumerableERC20Template;
    address payable public override protocolFeeRecipient;
    uint256 public override protocolFeeMultiplier;

    mapping(ICurve => bool) public bondingCurveAllowed;
    mapping(address => bool) public override callAllowed;
    mapping(LSSVMRouter => bool) public override routerAllowed;

    event PairCreated(address poolAddress, address nft);

    constructor(
        LSSVMPairETH _enumerableETHTemplate,
        LSSVMPairETH _missingEnumerableETHTemplate,
        LSSVMPairERC20 _enumerableERC20Template,
        LSSVMPairERC20 _missingEnumerableERC20Template,
        address payable _protocolFeeRecipient,
        uint256 _protocolFeeMultiplier
    ) {
        require(
            address(_enumerableETHTemplate) != address(0),
            "0 template address"
        );
        enumerableETHTemplate = _enumerableETHTemplate;

        require(
            address(_missingEnumerableETHTemplate) != address(0),
            "0 template address"
        );
        missingEnumerableETHTemplate = _missingEnumerableETHTemplate;

        require(
            address(_enumerableERC20Template) != address(0),
            "0 template address"
        );
        enumerableERC20Template = _enumerableERC20Template;

        require(
            address(_missingEnumerableERC20Template) != address(0),
            "0 template address"
        );
        missingEnumerableERC20Template = _missingEnumerableERC20Template;

        require(_protocolFeeRecipient != address(0), "0 recipient address");
        protocolFeeRecipient = _protocolFeeRecipient;

        require(_protocolFeeMultiplier <= MAX_PROTOCOL_FEE, "Fee too large");
        protocolFeeMultiplier = _protocolFeeMultiplier;
    }

    /**
     * External functions
     */

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _poolType Buy, Sell, or Trade
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price, in ETH
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
     */
    function createPairETH(
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external payable returns (LSSVMPairETH pair) {
        require(
            bondingCurveAllowed[_bondingCurve],
            "Bonding curve not whitelisted"
        );

        if (
            !ERC165Checker.supportsInterface(
                address(_nft),
                INTERFACE_ID_ERC721_ENUMERABLE
            )
        ) {
            pair = LSSVMPairETH(
                payable(address(missingEnumerableETHTemplate).clone())
            );
        } else {
            pair = LSSVMPairETH(
                payable(address(enumerableETHTemplate).clone())
            );
        }

        _initializePairETH(
            pair,
            _nft,
            _bondingCurve,
            _poolType,
            _delta,
            _fee,
            _spotPrice,
            _initialNFTIDs
        );
        emit PairCreated(address(pair), address(_nft));
    }

    /**
        @notice Creates a pair contract using EIP-1167. Uses CREATE2 for deterministic address.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _poolType Buy, Sell, or Trade
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price, in ETH
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
        @param _salt The salt value used by CREATE2
     */
    function createPairETHDeterministic(
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        bytes32 _salt
    ) external payable returns (LSSVMPairETH pair) {
        require(
            bondingCurveAllowed[_bondingCurve],
            "Bonding curve not whitelisted"
        );
        if (
            !ERC165Checker.supportsInterface(
                address(_nft),
                INTERFACE_ID_ERC721_ENUMERABLE
            )
        ) {
            pair = LSSVMPairETH(
                payable(
                    address(missingEnumerableETHTemplate).cloneDeterministic(
                        _salt
                    )
                )
            );
        } else {
            pair = LSSVMPairETH(
                payable(
                    address(enumerableETHTemplate).cloneDeterministic(_salt)
                )
            );
        }
        _initializePairETH(
            pair,
            _nft,
            _bondingCurve,
            _poolType,
            _delta,
            _fee,
            _spotPrice,
            _initialNFTIDs
        );
    }

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _poolType Buy, Sell, or Trade
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price, in ETH
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
     */
    function createPairERC20(
        IERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external returns (LSSVMPairERC20 pair) {
        require(
            bondingCurveAllowed[_bondingCurve],
            "Bonding curve not whitelisted"
        );

        if (
            !ERC165Checker.supportsInterface(
                address(_nft),
                INTERFACE_ID_ERC721_ENUMERABLE
            )
        ) {
            pair = LSSVMPairERC20(
                payable(address(missingEnumerableERC20Template).clone())
            );
        } else {
            pair = LSSVMPairERC20(
                payable(address(enumerableERC20Template).clone())
            );
        }

        _initializePairERC20(
            pair,
            _token,
            _nft,
            _bondingCurve,
            _poolType,
            _delta,
            _fee,
            _spotPrice,
            _initialNFTIDs
        );
        emit PairCreated(address(pair), address(_nft));
    }

    /**
        @notice Creates a pair contract using EIP-1167. Uses CREATE2 for deterministic address.
        @param _nft The NFT contract of the collection the pair trades
        @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
        @param _poolType Buy, Sell, or Trade
        @param _delta The delta value used by the bonding curve. The meaning of delta depends
        on the specific curve.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param _spotPrice The initial selling spot price, in ETH
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
        @param _salt The salt value used by CREATE2
     */
    function createPairERC20Deterministic(
        IERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        bytes32 _salt
    ) external returns (LSSVMPairERC20 pair) {
        require(
            bondingCurveAllowed[_bondingCurve],
            "Bonding curve not whitelisted"
        );
        if (
            !ERC165Checker.supportsInterface(
                address(_nft),
                INTERFACE_ID_ERC721_ENUMERABLE
            )
        ) {
            pair = LSSVMPairERC20(
                address(missingEnumerableERC20Template).cloneDeterministic(
                    _salt
                )
            );
        } else {
            pair = LSSVMPairERC20(
                address(enumerableERC20Template).cloneDeterministic(_salt)
            );
        }
        _initializePairERC20(
            pair,
            _token,
            _nft,
            _bondingCurve,
            _poolType,
            _delta,
            _fee,
            _spotPrice,
            _initialNFTIDs
        );
    }

    /**
        @notice Predicts the address of a pair for a 721 with Enumerable deployed using CREATE2, given the salt value.
        @param _salt The salt value used by CREATE2
     */
    function predictEnumerableETHPairAddress(bytes32 _salt)
        external
        view
        returns (address pairAddress)
    {
        return
            address(enumerableETHTemplate).predictDeterministicAddress(_salt);
    }

    /**
        @notice Predicts the address of a pair for a 721 without Enumerable deployed using CREATE2, given the salt value.
        @param _salt The salt value used by CREATE2
     */
    function predictMissingEnumerableETHPairAddress(bytes32 _salt)
        external
        view
        returns (address pairAddress)
    {
        return
            address(missingEnumerableETHTemplate).predictDeterministicAddress(
                _salt
            );
    }

    /**
        @notice Predicts the address of a pair for a 721 with Enumerable deployed using CREATE2, given the salt value.
        @param _salt The salt value used by CREATE2
     */
    function predictEnumerableERC20PairAddress(bytes32 _salt)
        external
        view
        returns (address pairAddress)
    {
        return
            address(enumerableERC20Template).predictDeterministicAddress(_salt);
    }

    /**
        @notice Predicts the address of a pair for a 721 without Enumerable deployed using CREATE2, given the salt value.
        @param _salt The salt value used by CREATE2
     */
    function predictMissingEnumerableERC20PairAddress(bytes32 _salt)
        external
        view
        returns (address pairAddress)
    {
        return
            address(missingEnumerableERC20Template).predictDeterministicAddress(
                _salt
            );
    }

    /**
     * Admin functions
     */

    /**
        @notice Changes the protocol fee recipient address. Only callable by the owner.
        @param _protocolFeeRecipient The new fee recipient
     */
    function changeProtocolFeeRecipient(address payable _protocolFeeRecipient)
        external
        onlyOwner
    {
        require(_protocolFeeRecipient != address(0), "0 address");
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    /**
        @notice Changes the protocol fee multiplier. Only callable by the owner.
        @param _protocolFeeMultiplier The new fee multiplier, 18 decimals
     */
    function changeProtocolFeeMultiplier(uint256 _protocolFeeMultiplier)
        external
        onlyOwner
    {
        require(_protocolFeeMultiplier <= MAX_PROTOCOL_FEE, "Fee too large");
        protocolFeeMultiplier = _protocolFeeMultiplier;
    }

    /**
        @notice Sets the whitelist status of a bonding curve contract. Only callable by the owner.
        @param bondingCurve The bonding curve contract
        @param isAllowed True to whitelist, false to remove from whitelist
     */
    function setBondingCurveAllowed(ICurve bondingCurve, bool isAllowed)
        external
        onlyOwner
    {
        bondingCurveAllowed[bondingCurve] = isAllowed;
    }

    /**
        @notice Sets the whitelist status of a contract to be called arbitrarily by a pair.
        Only callable by the owner.
        @param target The target contract
        @param isAllowed True to whitelist, false to remove from whitelist
     */
    function setCallAllowed(address target, bool isAllowed) external onlyOwner {
        callAllowed[target] = isAllowed;
    }

    /**
        @notice Updates the router whitelist. Only callable by the owner.
        @param _router The router
        @param isAllowed True to whitelist, false to remove from whitelist
     */
    function setRouterAllowed(LSSVMRouter _router, bool isAllowed)
        external
        onlyOwner
    {
        require(address(_router) != address(0), "0 router address");
        routerAllowed[_router] = isAllowed;
    }

    /**
     * Internal functions
     */

    function _initializePairETH(
        LSSVMPairETH _pair,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) internal {
        // initialize pair
        _pair.initialize(
            _nft,
            _bondingCurve,
            this,
            _poolType,
            _delta,
            _fee,
            _spotPrice
        );
        _pair.transferOwnership(msg.sender);

        // transfer initial ETH to pair
        payable(address(_pair)).sendValue(msg.value);

        // transfer initial NFTs from sender to pair
        for (uint256 i = 0; i < _initialNFTIDs.length; i++) {
            _nft.safeTransferFrom(
                msg.sender,
                address(_pair),
                _initialNFTIDs[i]
            );
        }
    }

    function _initializePairERC20(
        LSSVMPairERC20 _pair,
        IERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) internal {
        // initialize pair
        _pair.initialize(
            _token,
            _nft,
            _bondingCurve,
            this,
            _poolType,
            _delta,
            _fee,
            _spotPrice
        );
        _pair.transferOwnership(msg.sender);

        // transfer initial tokens to pair
        // TODO

        // transfer initial NFTs from sender to pair
        for (uint256 i = 0; i < _initialNFTIDs.length; i++) {
            _nft.safeTransferFrom(
                msg.sender,
                address(_pair),
                _initialNFTIDs[i]
            );
        }
    }
}
