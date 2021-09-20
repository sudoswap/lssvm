// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
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

    enum PoolType {
        Buy,
        Sell,
        Trade
    }

    uint256 private constant MAX_FEE = 9e17; // 90%, must <= 1 - MAX_PROTOCOL_FEE
    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE =
        type(IERC721Enumerable).interfaceId;

    // Note: we only call the enumerable functions when available
    IERC721Enumerable public nft;
    bool public missingEnumerable;
    EnumerableSet.UintSet private idSet;

    ICurve public bondingCurve;
    LSSVMPairFactory public factory;
    PoolType public poolType;
    uint256 public spotPrice;
    uint256 public delta;
    uint256 public fee;

    function initialize(
        address _nftAddress,
        address _curveAddress,
        LSSVMPairFactory _factory,
        PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice
    ) external payable initializer {
        if (
            !ERC165Checker.supportsInterface(
                _nftAddress,
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
        require(
            ICurve(_curveAddress).validateDelta(_delta),
            "Invalid delta for curve"
        );
        factory = _factory;
        nft = IERC721Enumerable(_nftAddress);
        bondingCurve = ICurve(_curveAddress);
        poolType = _poolType;
        delta = _delta;
        fee = _fee;
        spotPrice = _spotPrice;
        __Ownable_init();
    }

    // Sell X ETH to Pool, get back at least Y NFTs
    function swapETHForAnyNFTs(uint256 numNFTs) external payable nonReentrant {
        IERC721Enumerable _nft = nft;
        LSSVMPairFactory _factory = factory;
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
                uint256 nftId = _nft.tokenOfOwnerByIndex(address(this), 0);
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

    // Sell X ETH to Pool, get back at least Y specific NFTs
    function swapETHForNFTs(uint256[] calldata nftIds)
        external
        payable
        nonReentrant
    {
        IERC721Enumerable _nft = nft;
        LSSVMPairFactory _factory = factory;
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
        }
        uint256 feeDifference = msg.value - inputAmount;
        if (feeDifference > 0) {
            payable(msg.sender).sendValue(feeDifference);
        }
        if (protocolFee > 0) {
            _factory.protocolFeeRecipient().sendValue(protocolFee);
        }
    }

    // Sell X specific NFTs to Pool, get back at least Y ETH
    function swapNFTsForETH(
        uint256[] calldata nftIds,
        uint256 minExpectedETHOutput
    ) external nonReentrant {
        IERC721Enumerable _nft = nft;
        LSSVMPairFactory _factory = factory;
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

    // Withdraw X ETH
    function withdrawETH(uint256 amount) public onlyOwner {
        payable(owner()).sendValue(amount);
    }

    // Withdraw all ETH
    function withdrawAllETH() public onlyOwner {
        withdrawETH(address(this).balance);
    }

    // Withdraw Y NFTs
    function withdrawNFTs(uint256[] calldata nftIds) public onlyOwner {
        IERC721Enumerable _nft = nft;
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

    function onERC721Received(
        address a1,
        address a2,
        uint256 id,
        bytes memory b
    ) public virtual override returns (bytes4) {
        require(msg.sender == address(nft), "Invalid NFT received");
        if (missingEnumerable) {
            idSet.add(id);
        }
        return super.onERC721Received(a1, a2, id, b);
    }

    function changeSpotPrice(uint256 newSpotPrice) external onlyOwner {
        spotPrice = newSpotPrice;
    }

    function changeDelta(uint256 newDelta) external onlyOwner {
        require(
            bondingCurve.validateDelta(newDelta),
            "Invalid delta for curve"
        );
        delta = newDelta;
    }

    function changeFee(uint256 newFee) external onlyOwner {
        require(poolType == PoolType.Trade, "Only for Trade pools");
        require(newFee < MAX_FEE, "Trade fee must be less than 90%");
        fee = newFee;
    }

    receive() external payable {}
}
