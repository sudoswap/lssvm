// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMPairETH} from "./LSSVMPairETH.sol";
import {LSSVMPairEnumerable} from "./LSSVMPairEnumerable.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";

contract LSSVMPairEnumerableETH is LSSVMPairEnumerable, LSSVMPairETH {
    function pairVariant()
        public
        pure
        override
        returns (LSSVMPairFactoryLike.PairVariant)
    {
        return LSSVMPairFactoryLike.PairVariant.ENUMERABLE_ETH;
    }
}
