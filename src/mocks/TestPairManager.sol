// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IOwnershipTransferCallback} from "../lib/IOwnershipTransferCallback.sol";

contract TestPairManager is IOwnershipTransferCallback {
    address public prevOwner;

    constructor() {}

    function onOwnershipTransfer(address a) public {
        prevOwner = a;
    }
}
