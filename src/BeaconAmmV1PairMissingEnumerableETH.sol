// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {BeaconAmmV1PairETH} from "./BeaconAmmV1PairETH.sol";
import {BeaconAmmV1PairMissingEnumerable} from "./BeaconAmmV1PairMissingEnumerable.sol";
import {IBeaconAmmV1PairFactory} from "./IBeaconAmmV1PairFactory.sol";

contract BeaconAmmV1PairMissingEnumerableETH is
    BeaconAmmV1PairMissingEnumerable,
    BeaconAmmV1PairETH
{
    function pairVariant()
        public
        pure
        override
        returns (IBeaconAmmV1PairFactory.PairVariant)
    {
        return IBeaconAmmV1PairFactory.PairVariant.MISSING_ENUMERABLE_ETH;
    }
}
