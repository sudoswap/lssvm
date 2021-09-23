// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";
import {LSSVMPair} from "./LSSVMPair.sol";

contract LSSVMPairFactory is Ownable {
    using Clones for address;

    uint256 internal constant MAX_PROTOCOL_FEE = 1e17; // 10%, must <= 1 - MAX_FEE

    LSSVMPair public template;
    address payable public protocolFeeRecipient;
    uint256 public protocolFeeMultiplier;

    constructor(
        LSSVMPair _template,
        address payable _protocolFeeRecipient,
        uint256 _protocolFeeMultiplier
    ) {
        require(address(_template) != address(0), "0 template address");
        template = _template;

        require(_protocolFeeRecipient != address(0), "0 recipient address");
        protocolFeeRecipient = _protocolFeeRecipient;

        require(_protocolFeeMultiplier <= MAX_PROTOCOL_FEE, "Fee too large");
        protocolFeeMultiplier = _protocolFeeMultiplier;
    }

    function createPair(
        IERC721 _nft,
        ICurve _bondingCurve,
        LSSVMPair.PoolType _poolType,
        uint256 _delta,
        uint256 _fee,
        uint256 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external returns (LSSVMPair pair) {
        // deploy pair
        pair = LSSVMPair(payable(address(template).clone()));
        pair.initialize(
            _nft,
            _bondingCurve,
            this,
            _poolType,
            _delta,
            _fee,
            _spotPrice
        );
        pair.transferOwnership(msg.sender);

        // transfer initial NFTs from sender to pair
        for (uint256 i = 0; i < _initialNFTIDs.length; i++) {
            _nft.safeTransferFrom(msg.sender, address(pair), _initialNFTIDs[i]);
        }
    }

    function changeTemplate(LSSVMPair _template) external onlyOwner {
        require(address(_template) != address(0), "0 template address");
        template = _template;
    }

    function changeProtocolFeeRecipient(address payable _protocolFeeRecipient)
        external
        onlyOwner
    {
        require(_protocolFeeRecipient != address(0), "0 address");
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    function changeProtocolFeeMultiplier(uint256 _protocolFeeMultiplier)
        external
        onlyOwner
    {
        require(_protocolFeeMultiplier <= MAX_PROTOCOL_FEE, "Fee too large");
        protocolFeeMultiplier = _protocolFeeMultiplier;
    }
}
