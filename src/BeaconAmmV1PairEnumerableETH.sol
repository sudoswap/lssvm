// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1PairETH} from "./BeaconAmmV1PairETH.sol";
import {BeaconAmmV1PairEnumerable} from "./BeaconAmmV1PairEnumerable.sol";
import {IBeaconAmmV1PairFactoryLike} from "./IBeaconAmmV1PairFactoryLike.sol";

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
        returns (IBeaconAmmV1PairFactoryLike.PairVariant)
    {
        return IBeaconAmmV1PairFactoryLike.PairVariant.ENUMERABLE_ETH;
    }
}
