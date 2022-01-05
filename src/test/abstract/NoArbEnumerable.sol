// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Test721Enumerable} from "../../mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";

abstract contract NoArbEnumerable is NoArbBondingCurve {
  
    function setup721() public override returns (IERC721Mintable) {
        return IERC721Mintable(address(new Test721Enumerable()));
    }
}
