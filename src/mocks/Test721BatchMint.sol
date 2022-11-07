// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
import "./Test721.sol";

contract Test721BatchMint is Test721 {
    constructor() Test721() {}

    function batchMint(address to, uint256[] calldata ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            _mint(to, ids[i]);
        }
    }
}
