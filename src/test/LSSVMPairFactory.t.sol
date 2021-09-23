// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {LinearCurve} from "../bonding-curves/LinearCurve.sol";

import {LSSVMPairFactory} from "../LSSVMPairFactory.sol";
import {LSSVMPair} from "../LSSVMPair.sol";
import {Test721} from "../mocks/Test721.sol";
import {Hevm} from "./utils/Hevm.sol";

contract LSSVMPairFactoryTest is DSTest {
    Test721 test721;
    LinearCurve linearCurve;
    LSSVMPairFactory factory;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;

    function setUp() public {
        linearCurve = new LinearCurve();
        test721 = new Test721();
        LSSVMPair pairTemplate = new LSSVMPair();
        factory = new LSSVMPairFactory(
            pairTemplate,
            feeRecipient,
            protocolFeeMultiplier
        );
    }

    function test_createPair() public {
        uint256 delta = 0.1 ether;
        uint256 fee = 5e15;
        uint256 spotPrice = 1 ether;

        LSSVMPair pair = factory.createPair(
            test721,
            linearCurve,
            LSSVMPair.PoolType.Trade,
            delta,
            fee,
            spotPrice
        );

        // verify pair variables
        assertEq(address(pair.nft()), address(test721));
        assertEq(address(pair.bondingCurve()), address(linearCurve));
        assertEq(pair.fee(), fee);
        assertEq(pair.spotPrice(), spotPrice);
        assertEq(pair.owner(), address(this));
    }
}
