// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IOwnershipTransferCallback} from "../lib/IOwnershipTransferCallback.sol";

contract TestPairManager is IOwnershipTransferCallback {
    uint256 public isCallbackSet = 0;

    constructor() {}

    function onOwnershipTransfer() public {
        isCallbackSet = 1;
    }
}
