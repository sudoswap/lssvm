// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1ETH} from "./BeaconAmmV1ETH.sol";
import {BeaconAmmV1MissingEnumerable} from "./BeaconAmmV1MissingEnumerable.sol";
import {IBeaconAmmV1Factory} from "./IBeaconAmmV1Factory.sol";

contract BeaconAmmV1MissingEnumerableETH is
    BeaconAmmV1MissingEnumerable,
    BeaconAmmV1ETH
{
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1Factory.PairVariant)
    {
        return IBeaconAmmV1Factory.PairVariant.MISSING_ENUMERABLE_ETH;
    }
}
