// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {LSSVMRouterRobustBaseTest} from "./base/LSSVMRouterRobustBase.sol";
import {LinearCurve} from "../bonding-curves/LinearCurve.sol";
import {ICurve} from "../bonding-curves/ICurve.sol";
import {IERC721Mintable} from "./IERC721Mintable.sol";
import {Test721Enumerable} from "../mocks/Test721Enumerable.sol";

contract LSSVMRouterRobustEnumerableTest is LSSVMRouterRobustBaseTest {
    function setupCurve() public override returns (ICurve) {
        return new LinearCurve();
    }

    function setup721() public override returns (IERC721Mintable) {
        return IERC721Mintable(address(new Test721Enumerable()));
    }
}
