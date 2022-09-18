// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1Router} from "./BeaconAmmV1Router.sol";
import {IBeaconAmmV1RoyaltyManager} from "./IBeaconAmmV1RoyaltyManager.sol";

interface IBeaconAmmV1PairFactory {
    enum PairVariant {
        ENUMERABLE_ETH,
        MISSING_ENUMERABLE_ETH,
        ENUMERABLE_ERC20,
        MISSING_ENUMERABLE_ERC20
    }

    function protocolFeeMultiplier() external view returns (uint256);

    function protocolFeeRecipient() external view returns (address payable);

    function royaltyManager() external view returns (IBeaconAmmV1RoyaltyManager);
    
    function callAllowed(address target) external view returns (bool);

    function routerStatus(BeaconAmmV1Router router)
        external
        view
        returns (bool allowed, bool wasEverAllowed);

    function isPair(address potentialPair, PairVariant variant)
        external
        view
        returns (bool);
}
