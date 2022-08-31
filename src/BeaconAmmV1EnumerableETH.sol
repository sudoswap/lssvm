// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1ETH} from "./BeaconAmmV1ETH.sol";
import {BeaconAmmV1Enumerable} from "./BeaconAmmV1Enumerable.sol";
import {IBeaconAmmV1Factory} from "./IBeaconAmmV1Factory.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is ETH
    @author boredGenius and 0xmons
 */
contract BeaconAmmV1EnumerableETH is BeaconAmmV1Enumerable, BeaconAmmV1ETH {
    /**
        @notice Returns the BeaconAmmV1 type
     */
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1Factory.PairVariant)
    {
        return IBeaconAmmV1Factory.PairVariant.ENUMERABLE_ETH;
    }
}
