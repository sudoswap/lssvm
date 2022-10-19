// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {BeaconAmmV1Pair} from "../../BeaconAmmV1Pair.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {BeaconAmmV1PairFactory} from "../../BeaconAmmV1PairFactory.sol";
import {BeaconAmmV1RoyaltyManager} from "../../BeaconAmmV1RoyaltyManager.sol";

abstract contract Configurable {
    function getBalance(address a) public virtual returns (uint256);

    function setupRoyaltyManager(
        BeaconAmmV1PairFactory _factory,
        address _nft,
        uint256 _feeMultiplier,
        address payable _feeRecipient
    ) public returns (BeaconAmmV1RoyaltyManager) {
        BeaconAmmV1RoyaltyManager royaltyManager = new BeaconAmmV1RoyaltyManager(_factory);
        royaltyManager.addOperator(address(this));
        royaltyManager.addCreator(_nft, address(this));
        royaltyManager.setRoyaltyInfo(_nft, _feeMultiplier, _feeRecipient);
        return royaltyManager;
    }

    function setupPair(
        BeaconAmmV1PairFactory factory,
        IERC721 nft,
        ICurve bondingCurve,
        address payable assetRecipient,
        BeaconAmmV1Pair.PoolType poolType,
        uint128 delta,
        uint96 fee,
        uint128 spotPrice,
        uint256[] memory _idList,
        uint256 initialTokenBalance,
        address routerAddress /* Yes, this is weird, but due to how we encapsulate state for a Pair's ERC20 token, this is an easy way to set approval for the router.*/
    ) public payable virtual returns (BeaconAmmV1Pair);

    function setupCurve() public virtual returns (ICurve);

    function setup721() public virtual returns (IERC721Mintable);

    function modifyInputAmount(uint256 inputAmount)
        public
        virtual
        returns (uint256);

    function modifyDelta(uint64 delta) public virtual returns (uint64);

    function modifySpotPrice(uint56 spotPrice) public virtual returns (uint56);

    function sendTokens(BeaconAmmV1Pair pair, uint256 amount) public virtual;

    function withdrawTokens(BeaconAmmV1Pair pair) public virtual;

    function withdrawProtocolFees(BeaconAmmV1PairFactory factory) public virtual;

    function getTestToken() public virtual returns (address);

    receive() external payable {}
}
