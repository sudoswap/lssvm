// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1PairERC20} from "./BeaconAmmV1PairERC20.sol";
import {BeaconAmmV1PairEnumerable} from "./BeaconAmmV1PairEnumerable.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is an ERC20
    @author boredGenius and 0xmons
 */
contract BeaconAmmV1PairEnumerableERC20 is BeaconAmmV1PairEnumerable, BeaconAmmV1PairERC20 {
    /**
        @notice Returns the BeaconAmmV1Pair type
     */
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1PairFactory.PairVariant)
    {
        return IBeaconAmmV1PairFactory.PairVariant.ENUMERABLE_ERC20;
    }
}
