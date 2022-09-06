// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

contract Test2981 is ERC2981 {
    constructor(address receiver, uint96 bps) {
        _setDefaultRoyalty(receiver, bps);
    }
}
