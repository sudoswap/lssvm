// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract LSSVMPairFactory is Ownable {
    using Clones for address;
    using Address for address payable;

    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE = type(IERC721Enumerable).interfaceId;

    uint256 internal constant MAX_PROTOCOL_FEE = 1e17; // 10%, must <= 1 - MAX_FEE

    LSSVMPair public enumerableTemplate;
    LSSVMPair public missingEnumerableTemplate;
    address payable public protocolFeeRecipient;
    uint256 public protocolFeeMultiplier;

    mapping(ICurve => bool) public bondingCurveAllowed;
    mapping(address => bool) public callAllowed;
    mapping(LSSVMRouter => bool) public routerAllowed;

    event PairCreated(address poolAddress, address nft);

    constructor(
        LSSVMPair _enumerableTemplate,
        LSSVMPair _missingEnumerableTemplate,
        address payable _protocolFeeRecipient,
        uint256 _protocolFeeMultiplier
    ) {
        require(address(_enumerableTemplate) != address(0), "0 template address");
        enumerableTemplate = _enumerableTemplate;

        require(address(_missingEnumerableTemplate) != address(0), "0 template address");
        missingEnumerableTemplate = _missingEnumerableTemplate;

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
    function createPair(
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external payable returns (LSSVMPair pair) {
        
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
            pair = LSSVMPair(payable(address(missingEnumerableTemplate).clone()));
        }
        else {
            pair = LSSVMPair(payable(address(enumerableTemplate).clone()));
        }

        _initializePair(
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
    function createPairDeterministic(
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        bytes32 _salt
    ) external payable returns (LSSVMPair pair) {
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
            pair = LSSVMPair(payable(address(missingEnumerableTemplate).cloneDeterministic(_salt)));
        }
        else {
            pair = LSSVMPair(payable(address(enumerableTemplate).cloneDeterministic(_salt)));
        }
        _initializePair(
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
        @notice Predicts the address of a pair for a 721 with Enumerable deployed using CREATE2, given the salt value.
        @param _salt The salt value used by CREATE2
     */
    function predictEnumerablePairAddress(bytes32 _salt)
        external
        view
        returns (address pairAddress)
    {
        return address(enumerableTemplate).predictDeterministicAddress(_salt);
    }


    /**
        @notice Predicts the address of a pair for a 721 without Enumerable deployed using CREATE2, given the salt value.
        @param _salt The salt value used by CREATE2
     */
    function predictMissingEnumerablePairAddress(bytes32 _salt)
        external
        view
        returns (address pairAddress)
    {
        return address(missingEnumerableTemplate).predictDeterministicAddress(_salt);
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

    function _initializePair(
        LSSVMPair _pair,
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
}
