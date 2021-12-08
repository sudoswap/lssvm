// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "./bonding-curves/CurveErrorCodes.sol";
import {LSSVMPairFactory} from "./LSSVMPairFactory.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";
import {LSSVMPairERC20} from "./LSSVMPairERC20.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";

contract LSSVMPairEnumerableERC20 is LSSVMPairERC20 {
    function pairVariant()
        public
        pure
        override
        returns (LSSVMPairFactoryLike.PairVariant)
    {
        return LSSVMPairFactoryLike.PairVariant.ENUMERABLE_ERC20;
    }

    function _sendAnyNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256 numNFTs
    ) internal override {
        // Send NFTs to recipient
        // (we know nft implements IERC721Enumerable)
        for (uint256 i = 0; i < numNFTs; i++) {
            uint256 nftId = IERC721Enumerable(address(_nft))
                .tokenOfOwnerByIndex(address(this), 0);
            _nft.safeTransferFrom(address(this), nftRecipient, nftId);
        }
    }

    function _sendSpecificNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256[] calldata nftIds
    ) internal override {
        // Send NFTs to recipient
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(address(this), nftRecipient, nftIds[i]);
        }
    }

    function _takeNFTsFromSender(IERC721 _nft, uint256[] calldata nftIds)
        internal
        override
    {
        // Take in NFTs from caller
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(msg.sender, address(this), nftIds[i]);
        }
    }

    /**
       @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() external view override returns (uint256[] memory) {
        uint256 numNFTs = nft.balanceOf(address(this));
        uint256[] memory ids = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; i++) {
            ids[i] = IERC721Enumerable(address(nft)).tokenOfOwnerByIndex(
                address(this),
                i
            );
        }
        return ids;
    }

    /**
        @dev Callback when safeTransfering an ERC721 in
        If it's from the Router, we cache the current balance amount
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
        }
        return super.onERC721Received(operator, from, id, b);
    }

    function withdrawERC721(address a, uint256[] calldata nftIds)
        external
        override
        onlyOwner
        onlyUnlocked
    {
        for (uint256 i = 0; i < nftIds.length; i++) {
            IERC721(a).safeTransferFrom(address(this), msg.sender, nftIds[i]);
        }
    }
}
