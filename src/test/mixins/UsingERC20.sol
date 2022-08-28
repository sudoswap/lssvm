// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {NoArbBondingCurve} from "../base/NoArbBondingCurve.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairERC20} from "../../LSSVMPairERC20.sol";
import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {LSSVMRouter2} from "../../LSSVMRouter2.sol";
import {Test20} from "../../mocks/Test20.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {Configurable} from "./Configurable.sol";
import {RouterCaller} from "./RouterCaller.sol";

abstract contract UsingERC20 is Configurable, RouterCaller {
    using SafeTransferLib for ERC20;
    ERC20 test20;

    function modifyInputAmount(uint256) public pure override returns (uint256) {
        return 0;
    }

    function getBalance(address a) public view override returns (uint256) {
        return test20.balanceOf(a);
    }

    function sendTokens(LSSVMPair pair, uint256 amount) public override {
        test20.safeTransfer(address(pair), amount);
    }

    function setupPair(
        LSSVMPairFactory factory,
        IERC721 nft,
        ICurve bondingCurve,
        address payable assetRecipient,
        LSSVMPair.PoolType poolType,
        uint128 delta,
        uint96 fee,
        uint128 spotPrice,
        uint256[] memory _idList,
        uint256 initialTokenBalance,
        address routerAddress
    ) public payable override returns (LSSVMPair) {
        // create ERC20 token if not already deployed
        if (address(test20) == address(0)) {
            test20 = new Test20();
        }

        // set approvals for factory and router
        test20.approve(address(factory), type(uint256).max);
        test20.approve(routerAddress, type(uint256).max);

        // mint enough tokens to caller
        IMintable(address(test20)).mint(address(this), 1000 ether);

        // initialize the pair
        LSSVMPair pair = factory.createPairERC20(
            LSSVMPairFactory.CreateERC20PairParams(
                test20,
                nft,
                bondingCurve,
                assetRecipient,
                poolType,
                delta,
                fee,
                spotPrice,
                _idList,
                initialTokenBalance
            )
        );

        // Set approvals for pair
        test20.approve(address(pair), type(uint256).max);

        return pair;
    }

    function withdrawTokens(LSSVMPair pair) public override {
        uint256 total = test20.balanceOf(address(pair));
        LSSVMPairERC20(address(pair)).withdrawERC20(test20, total);
    }

    function withdrawProtocolFees(LSSVMPairFactory factory) public override {
        factory.withdrawERC20ProtocolFees(
            test20,
            test20.balanceOf(address(factory))
        );
    }

    function swapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapERC20ForAnyNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function swapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapERC20ForSpecificNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForAnyNFTsThroughToken(
        LSSVMRouter router,
        LSSVMRouter.NFTsForAnyNFTsTrade calldata trade,
        uint256 minOutput,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForAnyNFTsThroughERC20(
                trade,
                inputAmount,
                minOutput,
                nftRecipient,
                deadline
            );
    }

    function swapNFTsForSpecificNFTsThroughToken(
        LSSVMRouter router,
        LSSVMRouter.NFTsForSpecificNFTsTrade calldata trade,
        uint256 minOutput,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.swapNFTsForSpecificNFTsThroughERC20(
                trade,
                inputAmount,
                minOutput,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.RobustPairSwapAny[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.robustSwapERC20ForAnyNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.RobustPairSwapSpecific[] calldata swapList,
        address payable,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable override returns (uint256) {
        return
            router.robustSwapERC20ForSpecificNFTs(
                swapList,
                inputAmount,
                nftRecipient,
                deadline
            );
    }

    function robustSwapTokenForSpecificNFTsAndNFTsForTokens(
        LSSVMRouter router,
        LSSVMRouter.RobustPairNFTsFoTokenAndTokenforNFTsTrade calldata params
    ) public payable override returns (uint256, uint256) {
        return router.robustSwapERC20ForSpecificNFTsAndNFTsToToken(params);
    }

    function buyAndSellWithPartialFill(
        LSSVMRouter2 router,
        LSSVMRouter2.PairSwapSpecificPartialFill[] calldata buyList,
        LSSVMRouter2.PairSwapSpecificPartialFillForToken[] calldata sellList
    ) public payable override returns (uint256) {
        require(false, "Unimplemented");
    }

    function swapETHForSpecificNFTs(
        LSSVMRouter2 router,
        LSSVMRouter2.RobustPairSwapSpecific[] calldata buyList
    ) public payable override returns (uint256) {
        require(false, "Unimplemented");
    }
}
