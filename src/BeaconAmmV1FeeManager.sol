// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBeaconAmmV1FeeManager} from "./IBeaconAmmV1FeeManager.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

contract BeaconAmmV1FeeManager is IBeaconAmmV1FeeManager, Ownable {

    /* ========== STRUCTS ========== */

    struct Royalty {
        address creator;
        // Royalty fee is a percentage of trade fees, and comes from LP earnings
        // Units are in base 1e18, example royal fee of 10% = 0.10e18 feeMultiplier
        uint feeMultiplier;
        address payable feeRecipient;
        mapping(address => uint) earnings; // token to earnings
    }

    /* ========== STATE VARIABLES ========== */

    IBeaconAmmV1PairFactory public immutable factory;

    mapping(address => bool) public override isOperator;

    uint256 internal constant MAX_ROYALTY_FEE = 0.20e18; // 20%
    mapping(address => Royalty) public royalties; // NFT to royalty info

    /* ========== CONSTUCTOR ========== */

    constructor(IBeaconAmmV1PairFactory _factory) {
        factory = _factory;
    }

    /* ========== VIEWS ========== */

    function hasRoyaltyFee(address _nft) external override returns (bool) {
        return royalties[_nft].feeRecipient != address(0) && royalties[_nft].feeMultiplier != 0;
    }

    function getCreator(address _nft) external override returns (address) {
        return royalties[_nft].creator;
    }

    function getFeeMultiplier(address _nft) external override returns (uint) {
        return royalties[_nft].feeMultiplier;
    }

    function getFeeRecipient(address _nft) external override returns (address payable) {
        return royalties[_nft].feeRecipient;
    }

    function getEarnings(address _nft, address _token) external override returns (uint) {
        return royalties[_nft].earnings[_token];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function recordEarning(
        IBeaconAmmV1PairFactory.PairVariant variant,
        address _nft,
        address _token,
        uint _earned
    ) external
      override {
        // verify caller is a trusted pair contract
        require(factory.isPair(msg.sender, variant), "Not pair");
        royalties[_nft].earnings[_token] += _earned;
        emit FeeEarned(msg.sender, _nft, _token, _earned);
    }

    /* ========== ADMIN FUNCTIONS ========== */

    // Owner can set Operator
    // Operator can set Creator
    // Creator can set royalty fee and recipient

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

    function setCreator(address _nft, address _creator) external override onlyOperator {
        require(_nft != address(0), "invalid NFT");
        require(_creator != address(0), "invalid creator");
        address oldCreator = royalties[_nft].creator;
        royalties[_nft].creator = _creator;
        emit SetCreator(_nft, oldCreator, _creator);
    }

    function setRoyaltyFeeMultiplier(address _nft, uint _feeMultiplier) external override onlyCreator(_nft) {
        require(_nft != address(0), "invalid NFT");
        require(_feeMultiplier <= MAX_ROYALTY_FEE, "Fee too large");
        uint oldFeeMultiplier = royalties[_nft].feeMultiplier;
        royalties[_nft].feeMultiplier = _feeMultiplier;
        emit SetRoyaltyFeeMultiplier(_nft, oldFeeMultiplier, _feeMultiplier);
    }

    function setRoyaltyFeeRecipient(address _nft, address payable _feeRecipient) external override onlyCreator(_nft) {
        require(_nft != address(0), "invalid NFT");
        require(_feeRecipient != address(0), "invalid recipient");
        address oldFeeRecipient = royalties[_nft].feeRecipient;
        royalties[_nft].feeRecipient = _feeRecipient;
        emit SetRoyaltyFeeRecipient(_nft, oldFeeRecipient, _feeRecipient);
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
    event SetCreator(address _nft, address _oldCreator, address _newCreator);
    event SetRoyaltyFeeMultiplier(address _nft, uint _oldFeeMultiplier, uint _newFeeMultiplier);
    event SetRoyaltyFeeRecipient(address _nft, address _oldFeeRecipient, address _newFeeRecipient);
    event FeeEarned(address _pair, address _nft, address _token, uint _earned);
}
