// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@pwnednomore/contracts/PTest.sol";
import {LSSVMPair} from "../../../LSSVMPair.sol";

abstract contract PNMBase is PTest {
    LSSVMPair targetPair;
    address agent;

    // test if there's a way for someone that is not the pool owner to withdraw
    // either ETH or NFTs deposited into a pool
    function invariantNoneOwnerCanNeverWithdraw() public {
        vm.prank(agent);
        (bool success, ) = address(this).call(
            abi.encodeWithSignature("withdrawTokens(address)", targetPair)
        );
        assert(!success);
    }
}
