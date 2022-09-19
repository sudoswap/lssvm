// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {BeaconAmmV1Pair} from "../../BeaconAmmV1Pair.sol";
import {BeaconAmmV1PairFactory} from "../../BeaconAmmV1PairFactory.sol";
import {BeaconAmmV1Router} from "../../BeaconAmmV1Router.sol";
import {BeaconAmmV1PairETH} from "../../BeaconAmmV1PairETH.sol";
import {Configurable} from "./Configurable.sol";
import {RouterCaller} from "./RouterCaller.sol";

abstract contract UsingETH is Configurable, RouterCaller {
    function modifyInputAmount(uint256 inputAmount)
        public
        pure
        override
        returns (uint256)
    {
        return inputAmount;
    }

    function getTestToken() public view override returns (address) {
        return address(0);
    }

    function getBalance(address a) public view override returns (uint256) {
        return a.balance;
    }

    function sendTokens(BeaconAmmV1Pair pair, uint256 amount) public override {
        payable(address(pair)).transfer(amount);
    }

    function setupPair(
        BeaconAmmV1PairFactory factory,
        IERC721 nft,
        ICurve bondingCurve,
        address payable assetRecipient,
        BeaconAmmV1Pair.PoolType poolType,
        uint128 delta,
        uint96 fee,
        uint128 spotPrice,
        uint256[] memory _idList,
        uint256,
        address
    ) public payable override returns (BeaconAmmV1Pair) {
        BeaconAmmV1PairETH pair = factory.createPairETH{value: msg.value}(
            nft,
            bondingCurve,
            assetRecipient,
            poolType,
            delta,
            fee,
            spotPrice,
            _idList
        );
        return pair;
    }

    function withdrawTokens(BeaconAmmV1Pair pair) public override {
        BeaconAmmV1PairETH(payable(address(pair))).withdrawAllETH();
    }

    function withdrawProtocolFees(BeaconAmmV1PairFactory factory) public override {
        factory.withdrawETHProtocolFees();
    }

    function swapTokenForAnyNFTs(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.PairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapETHForAnyNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function swapTokenForSpecificNFTs(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.PairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapETHForSpecificNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForAnyNFTsThroughToken(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForAnyNFTsThroughETH{value: msg.value}(
                trade,
                minOutput,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForSpecificNFTsThroughToken(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForSpecificNFTsThroughETH{value: msg.value}(
                trade,
                minOutput,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForAnyNFTs(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.RobustPairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.robustSwapETHForAnyNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTs(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.RobustPairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256
    ) public payable override returns (uint256) {
        return
            router.robustSwapETHForSpecificNFTs{value: msg.value}(
                swapList,
                ethRecipient,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTsAndNFTsForTokens(
        BeaconAmmV1Router router,
        BeaconAmmV1Router.RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    ) public payable override returns (uint256, uint256) {
        return router.robustSwapETHForSpecificNFTsAndNFTsToToken{value: msg.value}(params);
    }
}
