// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBeaconAmmV1RoyaltyManager} from "./IBeaconAmmV1RoyaltyManager.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

contract BeaconAmmV1RoyaltyManager is IBeaconAmmV1RoyaltyManager, Ownable {

    /* ========== STRUCTS ========== */

    struct Royalty {
        address creator;
        // Royalty fee is a percentage of trade fees, and comes from LP earnings
        // Units are in base 1e18, example royal fee of 10% = 0.10e18 feeMultiplier
        uint feeMultiplier;
        address payable feeRecipient;
    }

    /* ========== STATE VARIABLES ========== */

    IBeaconAmmV1PairFactory public immutable override factory;

    mapping(address => bool) public override isOperator;

    uint public maxFeeMultiplier;
    mapping(address => Royalty) public royalties; // NFT to royalty info
    mapping(address => address[]) public creatorCollections; // mapping of creators to their collections

    /* ========== CONSTUCTOR ========== */

    constructor(IBeaconAmmV1PairFactory _factory) {
        factory = _factory;
        maxFeeMultiplier = 2e17; // initialize to 20%
    }

    /* ========== VIEWS ========== */

    function getCreator(address _nft) external view override returns (address) {
        return royalties[_nft].creator;
    }

    function getFeeMultiplier(address _nft) external view override returns (uint) {
        return royalties[_nft].feeMultiplier;
    }

    function getFeeRecipient(address _nft) external view override returns (address payable) {
        return royalties[_nft].feeRecipient;
    }

    function getCreatorCollections(address _creator) external view override returns (address[] memory) {
        return creatorCollections[_creator];
    }

    /* ========== ADMIN FUNCTIONS ========== */

    // Owner can set Operator
    // Operator can set Creator
    // Creator can set royalty fee and recipient

    function setMaxFeeMultiplier(uint _maxFeeMultiplier) external override onlyOwner {
        require(_maxFeeMultiplier <= 1e18, "Max multiplier too large");
        maxFeeMultiplier = _maxFeeMultiplier;
    }

    function addOperator(address _operator) external override onlyOwner {
        require(!isOperator[_operator], "already operator");
        isOperator[_operator] = true;
        emit AddOperator(_operator);
    }

    function removeOperator(address _operator) external override onlyOwner {
        require(isOperator[_operator], "not operator");
        isOperator[_operator] = false;
        emit RemoveOperator(_operator);
    }

    function addCreator(address _nft, address _creator) external override onlyOperator {
        _addCreator(_nft, _creator);
    }

    function _addCreator(address _nft, address _creator) internal {
        require(_nft != address(0), "invalid NFT");
        require(_creator != address(0), "invalid creator");
        royalties[_nft].creator = _creator;
        creatorCollections[_creator].push(_nft);
        emit AddCreator(_nft, _creator);
    }

    function removeCreator(address _nft) external override onlyOperator {
        _removeCreator(_nft);
    }

    function _removeCreator(address _nft) internal {
        require(_nft != address(0), "invalid NFT");
        address creator = royalties[_nft].creator;
        require(creator != address(0), "no creatored added");
        royalties[_nft].creator = address(0);
        uint256 totalCollections = creatorCollections[creator].length;
        for (uint i=0; i<totalCollections; i++) {
            if (creatorCollections[creator][i] == _nft) {
                creatorCollections[creator][i] = creatorCollections[creator][totalCollections - 1];
                creatorCollections[creator].pop();
                break;
            }
        }
        emit RemoveCreator(_nft, creator);
    }

    function transferCreator(address _nft, address _newCreator) external override onlyCreator(_nft) {
        _removeCreator(_nft);
        _addCreator(_nft, _newCreator);
    }

    function setRoyaltyInfo(address _nft, uint _feeMultiplier, address payable _feeRecipient) external override onlyCreator(_nft) {
        require(_nft != address(0), "invalid NFT");
        require(_feeRecipient != address(0), "invalid recipient");
        require(_feeMultiplier <= maxFeeMultiplier, "Fee too large");
        uint oldFeeMultiplier = royalties[_nft].feeMultiplier;
        address oldFeeRecipient = royalties[_nft].feeRecipient;
        royalties[_nft].feeMultiplier = _feeMultiplier;
        royalties[_nft].feeRecipient = _feeRecipient;
        emit SetRoyaltyInfo(_nft, oldFeeMultiplier, _feeMultiplier, oldFeeRecipient, _feeRecipient);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(isOperator[msg.sender], "!operator");
        _;
    }

    modifier onlyCreator(address _nft) {
        require(msg.sender == royalties[_nft].creator, "!creator");
        _;
    }

    /* ========== EVENTS ========== */

    event AddOperator(address _operator);
    event RemoveOperator(address _operator);
    event AddCreator(address _nft, address _creator);
    event RemoveCreator(address _nft, address _creator);
    event SetRoyaltyInfo(address _nft, uint _oldFeeMultiplier, uint _newFeeMultiplier, address _oldFeeRecipient, address _newFeeRecipient);
}
