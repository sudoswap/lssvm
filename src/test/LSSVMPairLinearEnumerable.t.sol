// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {LinearCurve} from "../bonding-curves/LinearCurve.sol";
import {Test721Enumerable} from "../mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "./IERC721Mintable.sol";
import {ICurve} from "../bonding-curves/ICurve.sol";
import {LSSVMPairBaseTest} from "./base/LSSVMPairBase.sol";

contract LSSVMPairLinearEnumerableTest is DSTest, LSSVMPairBaseTest {
    function setupCurve() public override returns (ICurve) {
        return new LinearCurve();
    }

    function setup721() public override returns (IERC721Mintable) {
        return IERC721Mintable(address(new Test721Enumerable()));
    }
}
