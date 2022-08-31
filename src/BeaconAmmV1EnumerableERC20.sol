// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1ERC20} from "./BeaconAmmV1ERC20.sol";
import {BeaconAmmV1Enumerable} from "./BeaconAmmV1Enumerable.sol";
import {IBeaconAmmV1Factory} from "./IBeaconAmmV1Factory.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is an ERC20
    @author boredGenius and 0xmons
 */
contract BeaconAmmV1EnumerableERC20 is BeaconAmmV1Enumerable, BeaconAmmV1ERC20 {
    /**
        @notice Returns the BeaconAmmV1 type
     */
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1Factory.PairVariant)
    {
        return IBeaconAmmV1Factory.PairVariant.ENUMERABLE_ERC20;
    }
}
