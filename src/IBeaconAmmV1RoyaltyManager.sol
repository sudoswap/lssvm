// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

interface IBeaconAmmV1RoyaltyManager {

    /* ========== VIEWS ========== */

    function factory() external view returns (IBeaconAmmV1PairFactory);
    function getCreatorCollections(address _creator) external view returns (address[] memory);
    function getCreator(address _nft) external view returns (address);
    function getFeeMultiplier(address _nft) external view returns (uint);
    function getFeeRecipient(address _nft) external view returns (address payable);
    function isOperator(address _operator) external view returns (bool);

    /* ========== ADMIN FUNCTIONS ========== */

    function addOperator(address _operator) external;
    function removeOperator(address _operator) external;
    function addCreator(address _nft, address _creator) external;
    function removeCreator(address _nft) external;
    function transferCreator(address _nft, address _creator) external;
    function setRoyaltyInfo(address _nft, uint _feeMultiplier, address payable _feeRecipient) external;
    function setMaxFeeMultiplier(uint _maxFeeMultiplier) external;
}
