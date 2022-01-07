// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {LSSVMPairETH} from "../../LSSVMPairETH.sol";
import {Configurable} from "./Configurable.sol";

abstract contract UsingETH is Configurable {

    function modifyInputAmount(uint256 inputAmount) public override pure returns (uint256) {
      return inputAmount;
    }

    function getBalance(address a) public override view returns (uint256) {
        return a.balance;
    }

    function sendTokens(LSSVMPair pair, uint256 amount) public override {
        payable(address(pair)).transfer(amount);
    }

    function setupPair(
        LSSVMPairFactory factory, 
        IERC721 nft, 
        ICurve bondingCurve, 
        uint256 delta, 
        uint256 spotPrice, 
        uint256[] memory _idList, 
        uint256,
        address) public payable override returns (LSSVMPair) {
        LSSVMPairETH pair = factory.createPairETH{value: msg.value}(
            nft,
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