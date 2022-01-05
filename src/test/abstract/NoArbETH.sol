// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairETH} from "../../LSSVMPairETH.sol";

abstract contract NoArbETH is NoArbBondingCurve {

    function modifyInputAmount(uint256 inputAmount) public override pure returns (uint256) {
      return inputAmount;
    }

    function getBalance() public override view returns (uint256) {
        return address(this).balance;
    }

    function sendTokens(LSSVMPair pair, uint256 amount) public override {
        payable(address(pair)).transfer(amount);
    }

    function setupPair(uint256 delta, uint256 spotPrice, uint256[] memory _idList) public override returns (LSSVMPair) {
        // initialize the pair
        LSSVMPairETH pair = factory.createPairETH(
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            _idList
        );
        return pair;
    }

    function withdrawTokens(LSSVMPair pair) public override {
        LSSVMPairETH(payable(address(pair))).withdrawAllETH();
    }
}