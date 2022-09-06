// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {RoyaltyRegistry} from "manifoldxyz/RoyaltyRegistry.sol";

import {ICurve} from "../../bonding-curves/ICurve.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairETH} from "../../LSSVMPairETH.sol";
import {LSSVMPairERC20} from "../../LSSVMPairERC20.sol";
import {LSSVMPairEnumerableETH} from "../../LSSVMPairEnumerableETH.sol";
import {LSSVMPairMissingEnumerableETH} from "../../LSSVMPairMissingEnumerableETH.sol";
import {LSSVMPairEnumerableERC20} from "../../LSSVMPairEnumerableERC20.sol";
import {LSSVMPairMissingEnumerableERC20} from "../../LSSVMPairMissingEnumerableERC20.sol";
import {LSSVMRouterWithRoyalties, LSSVMRouter} from "../../LSSVMRouterWithRoyalties.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {ConfigurableWithRoyalties} from "../mixins/ConfigurableWithRoyalties.sol";
import {RouterCaller} from "../mixins/RouterCaller.sol";

abstract contract RouterSinglePoolWithRoyalties is
    DSTest,
    ERC721Holder,
    ConfigurableWithRoyalties,
    RouterCaller
{
    IERC721Mintable test721;
    ERC2981 test2981;
    RoyaltyRegistry royaltyRegistry;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;
    LSSVMPair pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    uint256 constant numInitialNFTs = 10;

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        test2981 = setup2981();
        royaltyRegistry = setupRoyaltyRegistry();
        royaltyRegistry.setRoyaltyLookupAddress(
            address(test721),
            address(test2981)
        );

        LSSVMPairEnumerableETH enumerableETHTemplate = new LSSVMPairEnumerableETH();
        LSSVMPairMissingEnumerableETH missingEnumerableETHTemplate = new LSSVMPairMissingEnumerableETH();
        LSSVMPairEnumerableERC20 enumerableERC20Template = new LSSVMPairEnumerableERC20();
        LSSVMPairMissingEnumerableERC20 missingEnumerableERC20Template = new LSSVMPairMissingEnumerableERC20();
        factory = new LSSVMPairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            feeRecipient,
            protocolFeeMultiplier
        );
        router = new LSSVMRouterWithRoyalties(factory);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // Setup pair parameters
        uint128 delta = 0 ether;
        uint128 spotPrice = 1 ether;
        uint256[] memory idList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
            idList[i - 1] = i;
        }

        // Create a pair with a spot price of 1 eth, 10 NFTs, and no price increases
        pair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            idList,
            10 ether,
            address(router)
        );

        // mint extra NFTs to this contract (i.e. to be held by the caller)
        for (uint256 i = numInitialNFTs + 1; i <= 2 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }

    function test_swapTokenForSingleAnyNFT() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);

        // calculate royalty and add it to the input amount
        uint256 royaltyAmount = calcRoyalty(inputAmount);
        inputAmount += royaltyAmount;

        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );

        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), royaltyAmount);
    }

    function test_swapTokenForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);

        // calculate royalty and add it to the input amount
        uint256 royaltyAmount = calcRoyalty(inputAmount);
        inputAmount += royaltyAmount;

        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );

        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), royaltyAmount);
    }

    function test_swapSingleNFTForToken() public {
        (, , , uint256 outputAmount, ) = pair.getSellNFTQuote(1);

        // calculate royalty and rm it from the output amount
        uint256 royaltyAmount = calcRoyalty(outputAmount);
        outputAmount -= outputAmount;

        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );

        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), royaltyAmount);
    }

    function testGas_swapSingleNFTForToken5Times() public {
        uint256 totalRoyaltyAmount;
        for (uint256 i = 1; i <= 5; i++) {
            (, , , uint256 outputAmount, ) = pair.getSellNFTQuote(1);

            // calculate royalty and rm it from the output amount
            uint256 royaltyAmount = calcRoyalty(outputAmount);
            outputAmount -= royaltyAmount;
            totalRoyaltyAmount += royaltyAmount;

            uint256[] memory nftIds = new uint256[](1);
            nftIds[0] = numInitialNFTs + i;
            LSSVMRouter.PairSwapSpecific[]
                memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
            swapList[0] = LSSVMRouter.PairSwapSpecific({
                pair: pair,
                nftIds: nftIds
            });
            router.swapNFTsForToken(
                swapList,
                outputAmount,
                payable(address(this)),
                block.timestamp
            );
        }
        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), totalRoyaltyAmount);
    }

    function test_swapSingleNFTForAnyNFT() public {
        uint256 totalRoyaltyAmount;
        // construct NFT to Token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory nftToTokenSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });
        (, , , uint256 salePrice, ) = nftToTokenSwapList[0]
            .pair
            .getSellNFTQuote(sellNFTIds.length);
        totalRoyaltyAmount += calcRoyalty(salePrice);

        // construct Token to NFT swap list
        LSSVMRouter.PairSwapAny[]
            memory tokenToNFTSwapList = new LSSVMRouter.PairSwapAny[](1);
        tokenToNFTSwapList[0] = LSSVMRouter.PairSwapAny({
            pair: pair,
            numItems: 1
        });

        (, , , uint256 buyPrice, ) = tokenToNFTSwapList[0].pair.getBuyNFTQuote(
            1
        );
        totalRoyaltyAmount += calcRoyalty(buyPrice);

        // NOTE: We send some tokens (more than enough) to cover the protocol fee needed
        uint256 inputAmount = 0.01 ether;
        inputAmount += totalRoyaltyAmount;

        this.swapNFTsForAnyNFTsThroughToken{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            LSSVMRouter.NFTsForAnyNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );

        // check that royalty has been issued
        require(
            getBalance(ROYALTY_RECEIVER) <=
                (totalRoyaltyAmount * 1_010) / 1_000,
            "too much"
        );
        require(
            getBalance(ROYALTY_RECEIVER) >=
                (totalRoyaltyAmount * 1_000) / 1_500,
            "too less"
        );
        /* NOTE: test is failing with XykCurve
         * reason: buyQuote is quoted before the nfts are sold
         * recurring to proximity tests
         */
        // assertEq(getBalance(ROYALTY_RECEIVER), totalRoyaltyAmount);
    }

    function test_swapSingleNFTForSpecificNFT() public {
        uint256 totalRoyaltyAmount;
        // construct NFT to token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory nftToTokenSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        (, , , uint256 salePrice, ) = nftToTokenSwapList[0]
            .pair
            .getSellNFTQuote(sellNFTIds.length);
        totalRoyaltyAmount += calcRoyalty(salePrice);

        // construct token to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory tokenToNFTSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        tokenToNFTSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: buyNFTIds
        });

        (, , , uint256 buyPrice, ) = tokenToNFTSwapList[0].pair.getBuyNFTQuote(
            buyNFTIds.length
        );
        totalRoyaltyAmount += calcRoyalty(buyPrice);

        // NOTE: We send some tokens (more than enough) to cover the protocol fee
        uint256 inputAmount = 0.01 ether;
        inputAmount += totalRoyaltyAmount;

        this.swapNFTsForSpecificNFTsThroughToken{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            LSSVMRouter.NFTsForSpecificNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );

        // check that royalty has been issued
        require(
            getBalance(ROYALTY_RECEIVER) <=
                (totalRoyaltyAmount * 1_010) / 1_000,
            "too much"
        );
        require(
            getBalance(ROYALTY_RECEIVER) >=
                (totalRoyaltyAmount * 1_000) / 1_500,
            "too less"
        );
        /* NOTE: test is failing with XykCurve
         * reason: buyQuote is quoted before the nfts are sold
         * recurring to proximity tests
         */
        // assertEq(getBalance(ROYALTY_RECEIVER), totalRoyaltyAmount);
    }

    function test_swapTokenforAny5NFTs() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(5);

        // calculate royalty and add it to the input amount
        uint256 royaltyAmount = calcRoyalty(inputAmount);
        inputAmount += royaltyAmount;

        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");

        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), royaltyAmount);
    }

    function test_swapTokenforSpecific5NFTs() public {
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        uint256[] memory nftIds = new uint256[](5);
        nftIds[0] = 1;
        nftIds[1] = 2;
        nftIds[2] = 3;
        nftIds[3] = 4;
        nftIds[4] = 5;
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(5);

        // calculate royalty and add it to the input amount
        uint256 royaltyAmount = calcRoyalty(inputAmount);
        inputAmount += royaltyAmount;

        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");

        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), royaltyAmount);
    }

    function test_swap5NFTsForToken() public {
        (, , , uint256 outputAmount, ) = pair.getSellNFTQuote(5);

        // calculate royalty and rm it from the output amount
        uint256 royaltyAmount = calcRoyalty(outputAmount);
        outputAmount -= royaltyAmount;

        uint256[] memory nftIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nftIds[i] = numInitialNFTs + i + 1;
        }
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            outputAmount,
            payable(address(this)),
            block.timestamp
        );

        // check that royalty has been issued
        assertEq(getBalance(ROYALTY_RECEIVER), royaltyAmount);
    }

    function testFail_swapTokenForSingleAnyNFTSlippage() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
        inputAmount = addRoyalty(inputAmount);

        inputAmount = inputAmount - 1 wei;
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function testFail_swapTokenForSingleSpecificNFTSlippage() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
        inputAmount = addRoyalty(inputAmount);

        inputAmount = inputAmount - 1 wei;
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function testFail_swapSingleNFTForNonexistentToken() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 sellAmount;
        (, , , sellAmount, ) = pair.getSellNFTQuote(1);
        sellAmount = subRoyalty(sellAmount);

        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }

    function testFail_swapTokenForAnyNFTsPastBalance() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({
            pair: pair,
            numItems: test721.balanceOf(address(pair)) + 1
        });
        uint256 inputAmount;
        (, , , inputAmount, ) = pair.getBuyNFTQuote(
            test721.balanceOf(address(pair)) + 1
        );
        inputAmount = addRoyalty(inputAmount);

        inputAmount = inputAmount + 1 wei;
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function testFail_swapSingleNFTForTokenWithEmptyList() public {
        uint256[] memory nftIds = new uint256[](0);
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 sellAmount;
        (, , , sellAmount, ) = pair.getSellNFTQuote(1);
        sellAmount = subRoyalty(sellAmount);

        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }
}
