// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1ERC20} from "./BeaconAmmV1ERC20.sol";
import {BeaconAmmV1MissingEnumerable} from "./BeaconAmmV1MissingEnumerable.sol";
import {IBeaconAmmV1Factory} from "./IBeaconAmmV1Factory.sol";

contract BeaconAmmV1MissingEnumerableERC20 is
    BeaconAmmV1MissingEnumerable,
    BeaconAmmV1ERC20
{
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1Factory.PairVariant)
    {
        return IBeaconAmmV1Factory.PairVariant.MISSING_ENUMERABLE_ERC20;
    }
}
