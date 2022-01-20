// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMRouter} from "./LSSVMRouter.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";

/**
    @title An NFT/Token pair for an NFT that implements ERC721Enumerable
    @author boredGenius and 0xmons
 */
abstract contract LSSVMPairEnumerable is LSSVMPair {
    /**
        @notice Sends some number of NFTs to a recipient address, ID agnostic
        @dev Even though we specify the NFT address here, this internal function is only 
        used to send NFTs associated with this specific pool.
        @param _nft The address of the NFT to send
        @param nftRecipient The receiving address for the NFTs
        @param numNFTs The number of NFTs to send  
     */
    function _sendAnyNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256 numNFTs
    ) internal override {
        // Send NFTs to recipient
        // (we know NFT implements IERC721Enumerable so we just iterate)
        for (uint256 i = 0; i < numNFTs; i++) {
            uint256 nftId = IERC721Enumerable(address(_nft))
                .tokenOfOwnerByIndex(address(this), 0);
            _nft.safeTransferFrom(address(this), nftRecipient, nftId);
        }
    }

    /**
        @notice Sends specific NFTs to a recipient address
        @dev Even though we specify the NFT address here, this internal function is only 
        used to send NFTs associated with this specific pool.
        @param _nft The address of the NFT to send
        @param nftRecipient The receiving address for the NFTs
        @param nftIds The specific IDs of NFTs to send  
     */
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

    /**
        @notice Takes NFTs from the caller and sends them into the pair's asset recipient
        @dev This is used by the LSSVMPair's swapNFTForToken function. 
        Practically, we expect most users to use the LSSVMRouter and
        instead the routerSwapNFTsforToken function will be called
        which will not use this function.
        @param _nft The NFT collection to take from
        @param nftIds The specific NFT IDs to take
     */
    function _takeNFTsFromSender(IERC721 _nft, uint256[] calldata nftIds)
        internal
        override
    {
        address _assetRecipient = getAssetRecipient();

        // Take in NFTs from caller
        for (uint256 i = 0; i < nftIds.length; i++) {
            _nft.safeTransferFrom(msg.sender, _assetRecipient, nftIds[i]);
        }
    }

    /**
       @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() external view override returns (uint256[] memory) {
        IERC721 _nft = nft();
        uint256 numNFTs = _nft.balanceOf(address(this));
        uint256[] memory ids = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; i++) {
            ids[i] = IERC721Enumerable(address(_nft)).tokenOfOwnerByIndex(
                address(this),
                i
            );
        }
        return ids;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
        @notice Withdraws ERC721s from the pair to the caller
        @dev Only callable by the pair owner
        @param a The NFT address
        @param nftIds The NFT IDs to withdraw
     */
    function withdrawERC721(address a, uint256[] calldata nftIds)
        external
        override
        onlyOwner
    {
        for (uint256 i = 0; i < nftIds.length; i++) {
            IERC721(a).safeTransferFrom(address(this), msg.sender, nftIds[i]);
        }
    }
}
