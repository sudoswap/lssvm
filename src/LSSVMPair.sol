// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";
import {LSSVMPairFactory} from "./LSSVMPairFactory.sol";

contract LSSVMPair is OwnableUpgradeable, ERC721Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address payable;

    // Note: Refactor to be ETH/NFT/TRADE
    enum PoolType {
        Buy,
        Sell,
        Trade
    }

    //
    uint256 private constant MAX_FEE = 9e17; // 90%, must <= 1 - MAX_PROTOCOL_FEE
    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE =
        type(IERC721Enumerable).interfaceId;

    // Global vars lookup
    LSSVMPairFactory public factory;

    // Collection address
    IERC721 public nft;

    // ID tracking
    bool public missingEnumerable;
    EnumerableSet.UintSet private idSet;

    // Pool pricing parameters
    ICurve public bondingCurve;
    PoolType public poolType;
    uint256 public spotPrice;
    uint256 public delta;

    // Fee is only relevant for TRADE pools
    uint256 public fee;

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
        if (
            !ERC165Checker.supportsInterface(
                address(_nft),
                INTERFACE_ID_ERC721_ENUMERABLE
            )
        ) {
            missingEnumerable = true;
        }
        if ((_poolType == PoolType.Buy) || (_poolType == PoolType.Sell)) {
            require(_fee == 0, "Only Trade Pools can have nonzero fee");
        }
        if (_poolType == PoolType.Trade) {
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
        @dev To compute the amount of ETH to send, call bondingCurve.getBuyInfo
        @param numNFTs The number of NFTs to purchase
     */
    function swapETHForAnyNFTs(uint256 numNFTs) external payable nonReentrant {
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;
        PoolType _poolType = poolType;
        require(
            _poolType == PoolType.Sell || _poolType == PoolType.Trade,
            "Wrong Pool type"
        );
        require(
            (numNFTs > 0) && (numNFTs <= _nft.balanceOf(address(this))),
            "Must ask for > 0 and < balanceOf NFTs"
        );
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputAmount,
            uint256 protocolFee
        ) = bondingCurve.getBuyInfo(
                spotPrice,
                delta,
                numNFTs,
                fee,
                _factory.protocolFeeMultiplier()
            );
        require(error == CurveErrorCodes.Error.OK, "Bonding curve error");
        require(msg.value >= inputAmount, "Sent too little ETH");
        spotPrice = newSpotPrice;
        if (!missingEnumerable) {
            for (uint256 i = 0; i < numNFTs; i++) {
                // we know nft implements IERC721Enumerable
                // so we do a hard type conversion
                uint256 nftId = IERC721Enumerable(address(_nft))
                    .tokenOfOwnerByIndex(address(this), 0);
                _nft.safeTransferFrom(address(this), msg.sender, nftId);
            }
        } else {
            for (uint256 i = 0; i < numNFTs; i++) {
                uint256 nftId = idSet.at(0);
                _nft.safeTransferFrom(address(this), msg.sender, nftId);
                idSet.remove(nftId);
            }
        }
        uint256 feeDifference = msg.value - inputAmount;
        if (feeDifference > 0) {
            payable(msg.sender).sendValue(feeDifference);
        }
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }
    }

    /**
        @notice Sends ETH to the pair in exchange for a specific set of NFTs
        @dev To compute the amount of ETH to send, call bondingCurve.getBuyInfo
        @param nftIds The list of IDs of the NFTs to purchase
     */
    function swapETHForNFTs(uint256[] calldata nftIds)
        external
        payable
        nonReentrant
    {
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;
        bool _missingEnumerable = missingEnumerable;
        PoolType _poolType = poolType;
        require(
            _poolType == PoolType.Sell || _poolType == PoolType.Trade,
            "Wrong Pool type"
        );
        require(
            (nftIds.length > 0) &&
                (nftIds.length <= _nft.balanceOf(address(this))),
            "Must ask for > 0 and < balanceOf NFTs"
        );
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 inputAmount,
            uint256 protocolFee
        ) = bondingCurve.getBuyInfo(
                spotPrice,
                delta,
                nftIds.length,
                fee,
                _factory.protocolFeeMultiplier()
            );
        require(error == CurveErrorCodes.Error.OK, "Bonding curve error");
        require(msg.value >= inputAmount, "Sent too little ETH");
        spotPrice = newSpotPrice;
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(address(this), msg.sender, nftIds[i]);
            // Remove from idSet if missingEnumerable
            if (_missingEnumerable) {
                idSet.remove(nftIds[i]);
            }
        }

        uint256 feeDifference = msg.value - inputAmount;
        if (feeDifference > 0) {
            payable(msg.sender).sendValue(feeDifference);
        }
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }
    }

    /**
        @notice Sends a set of NFTs to the pair in exchange for ETH
        @dev To compute the amount of ETH to that will be received, call bondingCurve.getSellInfo
        @param nftIds The list of IDs of the NFTs to sell to the pair
        @param minExpectedETHOutput The minimum acceptable ETH received by the sender. If the actual
        amount is less than this value, the transaction will be reverted.
     */
    function swapNFTsForETH(
        uint256[] calldata nftIds,
        uint256 minExpectedETHOutput
    ) external nonReentrant {
        IERC721 _nft = nft;
        LSSVMPairFactory _factory = factory;
        PoolType _poolType = poolType;
        require(
            _poolType == PoolType.Buy || _poolType == PoolType.Trade,
            "Wrong Pool type"
        );
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 outputAmount,
            uint256 protocolFee
        ) = bondingCurve.getSellInfo(
                spotPrice,
                delta,
                nftIds.length,
                fee,
                _factory.protocolFeeMultiplier()
            );
        require(error == CurveErrorCodes.Error.OK, "Bonding curve error");
        require(outputAmount >= minExpectedETHOutput, "Out too little ETH");
        spotPrice = newSpotPrice;
        if (!missingEnumerable) {
            for (uint256 i = 0; i < nftIds.length; i++) {
                _nft.safeTransferFrom(msg.sender, address(this), nftIds[i]);
            }
        } else {
            for (uint256 i = 0; i < nftIds.length; i++) {
                _nft.safeTransferFrom(msg.sender, address(this), nftIds[i]);
                idSet.add(nftIds[i]);
            }
        }
        if (outputAmount > 0) {
            payable(msg.sender).sendValue(outputAmount);
        }
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }
    }

    /**
     * Owner functions
     */

    /**
        @notice Withdraws all ETH owned by the pair to the owner address.
        Only callable by the owner.
     */
    function withdrawAllETH() external onlyOwner {
        withdrawETH(address(this).balance);
    }

    /**
        @notice Withdraws a specified amount of ETH owned by the pair to the owner address.
        Only callable by the owner.
        @param amount The amount of ETH to send to the owner. If the pair's balance is less than
        this value, the transaction will be reverted.
     */
    function withdrawETH(uint256 amount) public onlyOwner {
        payable(owner()).sendValue(amount);
    }

    /**
        @notice Withdraws a specified set of NFTs owned by the pair to the owner address.
        The NFTs must be part of the pair's collection. Only callable by the owner.
        @param nftIds The list of IDs of the NFTs to send to the owner
     */
    function withdrawNFTs(uint256[] calldata nftIds) external onlyOwner {
        IERC721 _nft = nft;
        if (!missingEnumerable) {
            for (uint256 i = 0; i < nftIds.length; i++) {
                _nft.safeTransferFrom(address(this), msg.sender, nftIds[i]);
            }
        } else {
            for (uint256 i = 0; i < nftIds.length; i++) {
                _nft.safeTransferFrom(address(this), msg.sender, nftIds[i]);
                idSet.remove(nftIds[i]);
            }
        }
    }

    /**
        @notice Rescues a specified set of NFTs owned by the pair to the owner address.
        The NFTs cannot be part of the pair's collection. Only callable by the owner.
        @param a The address of the NFT to transfer
        @param nftIds The list of IDs of the NFTs to send to the owner
     */
    function withdrawERC721(address a, uint256[] calldata nftIds)
        external
        onlyOwner
    {
        require(a != address(nft));
        for (uint256 i = 0; i < nftIds.length; i++) {
            IERC721(a).safeTransferFrom(address(this), msg.sender, nftIds[i]);
        }
    }

    /**
        @notice Rescues ERC20 tokens from the pair to the owner. Only callable by the owner.
        @param a The address of the token to transfer
        @param amount The amount of tokens to send to the owner
     */
    function withdrawERC20(address a, uint256 amount) external onlyOwner {
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
        @param newSpotPrice The new selling spot price value, in ETH
     */
    function changeSpotPrice(uint256 newSpotPrice) external onlyOwner {
        spotPrice = newSpotPrice;
    }

    /**
        @notice Updates the delta parameter. Only callable by the owner.
        @param newDelta The new delta parameter
     */
    function changeDelta(uint256 newDelta) external onlyOwner {
        require(
            bondingCurve.validateDelta(newDelta),
            "Invalid delta for curve"
        );
        delta = newDelta;
    }

    /**
        @notice Updates the fee taken by the LP. Only callable by the owner.
        Only callable if the pool is a Trade pool. Reverts if the fee is >=
        MAX_FEE.
        @param newFee The new LP fee percentage, 18 decimals
     */
    function changeFee(uint256 newFee) external onlyOwner {
        require(poolType == PoolType.Trade, "Only for Trade pools");
        require(newFee < MAX_FEE, "Trade fee must be less than 90%");
        fee = newFee;
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
        require(factory.callAllowed(target), "Target must be whitelisted");
        (bool result, ) = target.call{value: 0}(data);
        require(result, "Call failed");
    }

    /**
     * Utility functions (not to be called directly, but also not internal)
     */

    /**
        @dev All ETH transfers into the pair are accepted. This is the main method
        for the owner to top up the pair's ETH reserves.
     */
    receive() external payable {}

    /**
        @dev Callback when safeTransfering an ERC721 in, we add ID to the idSet
        if it's the same collection used by pool (and doesn't auto-track via enumerable)
     */
    function onERC721Received(
        address a1,
        address a2,
        uint256 id,
        bytes memory b
    ) public virtual override returns (bytes4) {
        if (missingEnumerable && msg.sender == address(nft)) {
            idSet.add(id);
        }
        return super.onERC721Received(a1, a2, id, b);
    }
}
