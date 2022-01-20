// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Test721} from "../../mocks/Test721.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Configurable} from "./Configurable.sol";

abstract contract UsingMissingEnumerable is Configurable {
    function setup721() public override returns (IERC721Mintable) {
        return IERC721Mintable(address(new Test721()));
    }
}
