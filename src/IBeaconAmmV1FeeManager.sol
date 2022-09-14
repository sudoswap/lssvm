// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

interface IBeaconAmmV1FeeManager {

    /* ========== VIEWS ========== */

    function hasRoyaltyFee(address _nft) external returns (bool);
    function getCreator(address _nft) external returns (address);
    function getFeeMultiplier(address _nft) external returns (uint);
    function getFeeRecipient(address _nft) external returns (address payable);
    function getEarnings(address _nft, address _token) external returns (uint);
    function isOperator(address _operator) external view returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function recordEarning(IBeaconAmmV1PairFactory.PairVariant variant, address _nft, address _token, uint _earned) external;

    /* ========== ADMIN FUNCTIONS ========== */

    function addOperator(address _operator) external;
    function removeOperator(address _operator) external;
    function setCreator(address _nft, address _creator) external;
    function setRoyaltyFeeMultiplier(address _nft, uint _feeMultiplier) external;
    function setRoyaltyFeeRecipient(address _nft, address payable _feeRecipient) external;
}
