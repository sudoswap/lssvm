// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";

contract Test20 is ERC20 {
    constructor() ERC20("Test20", "T20", 18) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
