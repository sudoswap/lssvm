// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMPairETH} from "./LSSVMPairETH.sol";
import {LSSVMPairERC20} from "./LSSVMPairERC20.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";

contract LSSVMPairFactory is Ownable, LSSVMPairFactoryLike {
    using Clones for address;
    using SafeTransferLib for address payable;
    using SafeTransferLib for ERC20;

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
        @return pair The new pair
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
        @return pair The new pair
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
        emit PairCreated(address(pair), address(_nft));
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
        @param _initialTokenBalance The initial token balance sent from the sender to the new pair
        @return pair The new pair
     */
    function createPairERC20(
        ERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        uint256 _initialTokenBalance
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
            _initialNFTIDs,
            _initialTokenBalance
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
        @param _initialTokenBalance The initial token balance sent from the sender to the new pair
        @param _salt The salt value used by CREATE2
        @return pair The new pair
     */
    function createPairERC20Deterministic(
        ERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        uint256 _initialTokenBalance,
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
            _initialNFTIDs,
            _initialTokenBalance
        );
        emit PairCreated(address(pair), address(_nft));
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
        @notice Checks if an address is a LSSVMPair. Uses the fact that the pairs are EIP-1167 minimal proxies.
        @param potentialPair The address to check
        @param variant The pair variant (NFT is enumerable or not, pair uses ETH or ERC20)
        @return True if the address is the specified pair variant, false otherwise
     */
    function isPair(address potentialPair, PairVariant variant)
        external
        view
        override
        returns (bool)
    {
        if (variant == PairVariant.ENUMERABLE_ETH) {
            return _isClone(potentialPair, address(enumerableETHTemplate));
        } else if (variant == PairVariant.MISSING_ENUMERABLE_ETH) {
            return
                _isClone(potentialPair, address(missingEnumerableETHTemplate));
        } else if (variant == PairVariant.ENUMERABLE_ERC20) {
            return _isClone(potentialPair, address(enumerableERC20Template));
        } else if (variant == PairVariant.MISSING_ENUMERABLE_ERC20) {
            return
                _isClone(
                    potentialPair,
                    address(missingEnumerableERC20Template)
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
     * Admin functions
     */

    /**
        @notice Withdraws the ETH balance to the protocol fee recipient.
        Only callable by the owner.
     */
    function withdrawETHProtocolFees() external onlyOwner {
        protocolFeeRecipient.safeTransferETH(address(this).balance);
    }

    /**
        @notice Withdraws ERC20 tokens to the protocol fee recipient. Only callable by the owner.
        @param token The token to transfer
     */
    function withdrawERC20ProtocolFees(ERC20 token) external onlyOwner {
        token.safeTransferFrom(
            address(this),
            protocolFeeRecipient,
            token.balanceOf(address(this))
        );
    }

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
    function setCallAllowed(address payable target, bool isAllowed)
        external
        onlyOwner
    {
        // ensure target is not a router
        if (isAllowed) {
            require(!routerAllowed[LSSVMRouter(target)], "Can't call router");
        }

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
        // ensure target is not arbitrarily callable by pairs
        if (isAllowed) {
            require(!callAllowed[address(_router)], "Can't call router");
        }
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
        payable(address(_pair)).safeTransferETH(msg.value);

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
        ERC20 _token,
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs,
        uint256 _initialTokenBalance
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
        _token.safeTransferFrom(
            msg.sender,
            address(_pair),
            _initialTokenBalance
        );

        // transfer initial NFTs from sender to pair
        for (uint256 i = 0; i < _initialNFTIDs.length; i++) {
            _nft.safeTransferFrom(
                msg.sender,
                address(_pair),
                _initialNFTIDs[i]
            );
        }
    }

    /**
        @dev Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        MIT license, Copyright (c) 2018 Murray Software, LLC.
     */
    function _isClone(address target, address query)
        internal
        view
        returns (bool result)
    {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), targetBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            let other := add(clone, 0x40)
            extcodecopy(query, other, 0, 0x2d)
            result := and(
                eq(mload(clone), mload(other)),
                eq(mload(add(clone, 0xd)), mload(add(other, 0xd)))
            )
        }
    }

    /** 
      @dev Used to deposit NFTs into a pair after creation
    */
    function depositNFTs(IERC721 _nft, uint256[] calldata ids, address recipient) external {
        // transfer initial NFTs from caller to recipient 
        for (uint256 i = 0; i < ids.length; i++) {
            _nft.safeTransferFrom(
                msg.sender,
                recipient,
                ids[i]
            );
        }
    }
}
