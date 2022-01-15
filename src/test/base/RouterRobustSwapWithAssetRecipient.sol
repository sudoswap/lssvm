// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairETH} from "../../LSSVMPairETH.sol";
import {LSSVMPairERC20} from "../../LSSVMPairERC20.sol";
import {LSSVMPairEnumerableETH} from "../../LSSVMPairEnumerableETH.sol";
import {LSSVMPairMissingEnumerableETH} from "../../LSSVMPairMissingEnumerableETH.sol";
import {LSSVMPairEnumerableERC20} from "../../LSSVMPairEnumerableERC20.sol";
import {LSSVMPairMissingEnumerableERC20} from "../../LSSVMPairMissingEnumerableERC20.sol";
import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Hevm} from "../utils/Hevm.sol";
import {Configurable} from "../mixins/Configurable.sol";
import {RouterCaller} from "../mixins/RouterCaller.sol";

abstract contract RouterRobustSwapWithAssetRecipient is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;

    // 2 Sell Pairs
    LSSVMPair sellPair1;
    LSSVMPair sellPair2;

    // 2 Buy Pairs
    LSSVMPair buyPair1;
    LSSVMPair buyPair2;

    address payable constant feeRecipient = payable(address(69));
    address payable constant sellPairRecipient = payable(address(1));
    address payable constant buyPairRecipient = payable(address(2));
    uint256 constant protocolFeeMultiplier = 0;
    uint256 constant numInitialNFTs = 10;

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        LSSVMPairETH enumerableETHTemplate = new LSSVMPairEnumerableETH();
        LSSVMPairETH missingEnumerableETHTemplate = new LSSVMPairMissingEnumerableETH();
        LSSVMPairERC20 enumerableERC20Template = new LSSVMPairEnumerableERC20();
        LSSVMPairERC20 missingEnumerableERC20Template = new LSSVMPairMissingEnumerableERC20();
        factory = new LSSVMPairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            feeRecipient,
            protocolFeeMultiplier
        );
        router = new LSSVMRouter(factory);

        // Set approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
        uint256 spotPrice = 1 ether;
        uint256 inputAmount = 1 ether;

        uint256[] memory sellIDList1 = new uint256[](1);
        sellIDList1[0] = 1;
        sellPair1 = this.setupPair{value: modifyInputAmount(inputAmount)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            modifyDelta(0),
            spotPrice,
            LSSVMPair.PoolType.NFT,
            sellIDList1,
            inputAmount,
            address(router)
        );

        uint256[] memory sellIDList2 = new uint256[](1);
        sellIDList2[0] = 2;
        sellPair2 = this.setupPair{value: modifyInputAmount(inputAmount)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            modifyDelta(0),
            spotPrice,
            LSSVMPair.PoolType.NFT,
            sellIDList2,
            inputAmount,
            address(router)
        );

        uint256[] memory buyIDList1 = new uint256[](1);
        buyIDList1[0] = 3;
        buyPair1 = this.setupPair{value: modifyInputAmount(inputAmount)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            modifyDelta(0),
            spotPrice,
            LSSVMPair.PoolType.TOKEN,
            buyIDList1,
            inputAmount,
            address(router)
        );

        uint256[] memory buyIDList2 = new uint256[](1);
        buyIDList2[0] = 4;
        buyPair2 = this.setupPair{value: modifyInputAmount(inputAmount)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            modifyDelta(0),
            spotPrice,
            LSSVMPair.PoolType.TOKEN,
            buyIDList2,
            inputAmount,
            address(router)
        );
    }

    // Swapping tokens for any NFT on sellPair1 works, but fails silently on sellPair2 if slippage is too tight
    function test_robustSwapTokenForAnyNFTs() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](2);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: sellPair1, numItems: 1});
        swapList[1] = LSSVMRouter.PairSwapAny({pair: sellPair2, numItems: 1});
        uint256 sellPair1Price;
        (, , sellPair1Price, ) = sellPair1.getBuyNFTQuote(1);
        uint256[] memory maxCostPerNFTSwap = new uint256[](2);
        maxCostPerNFTSwap[0] = sellPair1Price;
        maxCostPerNFTSwap[1] = 0 ether;
        uint256 inputAmount = 2 ether;
        uint256 remainingValue = this.robustSwapTokenForAnyNFTs{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            swapList,
            maxCostPerNFTSwap,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(remainingValue + sellPair1Price, inputAmount);
        assertEq(getBalance(sellPairRecipient), sellPair1Price);
    }

    // Swapping tokens to a specific NFT with sellPair2 works, but fails silently on sellPair1 if slippage is too tight
    function test_robustSwapTokenForSpecificNFTs() public {
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](2);
        uint256[] memory nftIds1 = new uint256[](1);
        nftIds1[0] = 1;
        uint256[] memory nftIds2 = new uint256[](1);
        nftIds2[0] = 2;
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: sellPair1,
            nftIds: nftIds1
        });
        swapList[1] = LSSVMRouter.PairSwapSpecific({
            pair: sellPair2,
            nftIds: nftIds2
        });
        uint256 sellPair1Price;
        (, , sellPair1Price, ) = sellPair2.getBuyNFTQuote(1);
        uint256[] memory maxCostPerNFTSwap = new uint256[](2);
        maxCostPerNFTSwap[0] = 0 ether;
        maxCostPerNFTSwap[1] = sellPair1Price;
        uint256 inputAmount = 2 ether;
        uint256 remainingValue = this.robustSwapTokenForSpecificNFTs{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            swapList,
            maxCostPerNFTSwap,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(remainingValue + sellPair1Price, inputAmount);
        assertEq(getBalance(sellPairRecipient), sellPair1Price);
    }

    // Swapping NFTs to tokens with buyPair1 works, but buyPair2 silently fails due to slippage
    function test_robustSwapNFTsForToken() public {
        uint256[] memory nftIds1 = new uint256[](1);
        nftIds1[0] = 5;
        uint256[] memory nftIds2 = new uint256[](1);
        nftIds2[0] = 6;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](2);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: buyPair1,
            nftIds: nftIds1
        });
        swapList[1] = LSSVMRouter.PairSwapSpecific({
            pair: buyPair2,
            nftIds: nftIds2
        });
        uint256 buyPair1Price;
        (, , buyPair1Price, ) = buyPair1.getSellNFTQuote(1);
        uint256[] memory minOutput = new uint256[](2);
        minOutput[0] = buyPair1Price;
        minOutput[1] = 2 ether;
        router.robustSwapNFTsForToken(
            swapList,
            minOutput,
            payable(address(this)),
            block.timestamp
        );
        assertEq(test721.balanceOf(buyPairRecipient), 1);
    }
}
