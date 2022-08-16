// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMRouter} from "./LSSVMRouter.sol";

contract LSSVMRouterWithRoyalty is LSSVMRouter, EIP2981Extension {
    // TODO: Add EIP2981 complaint versions of all sudoswap swap functions.
}
