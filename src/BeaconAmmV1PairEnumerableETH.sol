// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1PairETH} from "./BeaconAmmV1PairETH.sol";
import {BeaconAmmV1PairEnumerable} from "./BeaconAmmV1PairEnumerable.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is ETH
    @author boredGenius and 0xmons
 */
contract BeaconAmmV1PairEnumerableETH is BeaconAmmV1PairEnumerable, BeaconAmmV1PairETH {
    /**
        @notice Returns the BeaconAmmV1Pair type
     */
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1PairFactory.PairVariant)
    {
        return IBeaconAmmV1PairFactory.PairVariant.ENUMERABLE_ETH;
    }
}
