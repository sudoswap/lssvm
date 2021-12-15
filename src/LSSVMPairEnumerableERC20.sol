// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMPairERC20} from "./LSSVMPairERC20.sol";
import {LSSVMPairEnumerable} from "./LSSVMPairEnumerable.sol";
import {LSSVMPairFactoryLike} from "./LSSVMPairFactoryLike.sol";

contract LSSVMPairEnumerableERC20 is LSSVMPairEnumerable, LSSVMPairERC20 {
    function pairVariant()
        public
        pure
        override
        returns (LSSVMPairFactoryLike.PairVariant)
    {
        return LSSVMPairFactoryLike.PairVariant.ENUMERABLE_ERC20;
    }
}
