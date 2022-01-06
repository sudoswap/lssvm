// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairERC20} from "../../LSSVMPairERC20.sol";
import {Test20} from "../../mocks/Test20.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {Configurable} from "./Configurable.sol";

abstract contract UsingToken is Configurable {
    using SafeTransferLib for ERC20;
    ERC20 test20;

    event Balance(uint256 b);

    function modifyInputAmount(uint256) public override pure returns (uint256) {
      return 0;
    }

    function getBalance() public override view returns (uint256) {
        return test20.balanceOf(address(this));
    }

    function sendTokens(LSSVMPair pair, uint256 amount) public override {
        test20.safeTransfer(address(pair), amount);
    }

    function setupPair(LSSVMPairFactory factory, IERC721 nft, ICurve bondingCurve, uint256 delta, uint256 spotPrice, uint256[] memory _idList) public override returns (LSSVMPair) {

        // create ERC20 token
        test20 = new Test20();

        // initialize the pair
        LSSVMPair pair = factory.createPairERC20(
            test20,
            nft,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            _idList,
            0
        );

        // set approvals for factory and pair
        test20.approve(address(pair), type(uint256).max);
        test20.approve(address(factory), type(uint256).max);

        // mint enough tokens to caller
        IMintable(address(test20)).mint(address(this), 1000000000 ether);

        return pair;
    }

    function withdrawTokens(LSSVMPair pair) public override {
        uint256 total = test20.balanceOf(address(pair));
        LSSVMPairERC20(address(pair)).withdrawERC20(address(test20), total);
    }
}