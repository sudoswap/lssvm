// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ICurve} from "../../bonding-curves/ICurve.sol";
import {BeaconAmmV1PairFactory} from "../../BeaconAmmV1PairFactory.sol";
import {BeaconAmmV1RoyaltyManager} from "../../BeaconAmmV1RoyaltyManager.sol";
import {BeaconAmmV1Pair} from "../../BeaconAmmV1Pair.sol";
import {BeaconAmmV1PairETH} from "../../BeaconAmmV1PairETH.sol";
import {BeaconAmmV1PairERC20} from "../../BeaconAmmV1PairERC20.sol";
import {BeaconAmmV1PairEnumerableETH} from "../../BeaconAmmV1PairEnumerableETH.sol";
import {BeaconAmmV1PairMissingEnumerableETH} from "../../BeaconAmmV1PairMissingEnumerableETH.sol";
import {BeaconAmmV1PairEnumerableERC20} from "../../BeaconAmmV1PairEnumerableERC20.sol";
import {BeaconAmmV1PairMissingEnumerableERC20} from "../../BeaconAmmV1PairMissingEnumerableERC20.sol";
import {BeaconAmmV1Router} from "../../BeaconAmmV1Router.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Configurable} from "../mixins/Configurable.sol";
import {RouterCaller} from "../mixins/RouterCaller.sol";

abstract contract RouterSinglePool is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    BeaconAmmV1PairFactory factory;
    BeaconAmmV1RoyaltyManager royaltyManager;
    BeaconAmmV1Router router;
    BeaconAmmV1Pair pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    uint256 constant numInitialNFTs = 10;
    uint96 constant pairFee = 10e16;
    uint256 constant royaltyFeeMultiplier = 1e17; // 10%
    address payable constant royaltyFeeRecipient = payable(address(6));

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        BeaconAmmV1PairEnumerableETH enumerableETHTemplate = new BeaconAmmV1PairEnumerableETH();
        BeaconAmmV1PairMissingEnumerableETH missingEnumerableETHTemplate = new BeaconAmmV1PairMissingEnumerableETH();
        BeaconAmmV1PairEnumerableERC20 enumerableERC20Template = new BeaconAmmV1PairEnumerableERC20();
        BeaconAmmV1PairMissingEnumerableERC20 missingEnumerableERC20Template = new BeaconAmmV1PairMissingEnumerableERC20();
        factory = new BeaconAmmV1PairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            feeRecipient,
            protocolFeeMultiplier
        );
        router = new BeaconAmmV1Router(factory);
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
            BeaconAmmV1Pair.PoolType.TRADE,
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
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function test_swapTokenForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(1);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function test_swapSingleNFTForToken() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
    }

    function testGas_swapSingleNFTForToken5Times() public {
        for (uint256 i = 1; i <= 5; i++) {
            uint256[] memory nftIds = new uint256[](1);
            nftIds[0] = numInitialNFTs + i;
            BeaconAmmV1Router.PairSwapSpecific[]
                memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
            swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
                pair: pair,
                nftIds: nftIds
            });
            router.swapNFTsForToken(
                swapList,
                0.9 ether,
                payable(address(this)),
                block.timestamp
            );
        }
    }

    function test_swapSingleNFTForAnyNFT() public {
        // construct NFT to Token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct Token to NFT swap list
        BeaconAmmV1Router.PairSwapAny[]
            memory tokenToNFTSwapList = new BeaconAmmV1Router.PairSwapAny[](1);
        tokenToNFTSwapList[0] = BeaconAmmV1Router.PairSwapAny({
            pair: pair,
            numItems: 1
        });

        // NOTE: We send some tokens (more than enough) to cover the protocol fee needed
        uint256 inputAmount = 0.01 ether;
        this.swapNFTsForAnyNFTsThroughToken{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            BeaconAmmV1Router.NFTsForAnyNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function test_swapSingleNFTForSpecificNFT() public {
        // construct NFT to token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct token to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory tokenToNFTSwapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        tokenToNFTSwapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: buyNFTIds
        });

        // NOTE: We send some tokens (more than enough) to cover the protocol fee
        uint256 inputAmount = 0.01 ether;
        this.swapNFTsForSpecificNFTsThroughToken{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            BeaconAmmV1Router.NFTsForSpecificNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
    }

    function test_swapTokenforAny5NFTs() public {
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: pair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(5);
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
    }

    function test_swapTokenforSpecific5NFTs() public {
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        uint256[] memory nftIds = new uint256[](5);
        nftIds[0] = 1;
        nftIds[1] = 2;
        nftIds[2] = 3;
        nftIds[3] = 4;
        nftIds[4] = 5;
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(5);
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
    }

    function test_swap5NFTsForToken() public {
        uint256[] memory nftIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nftIds[i] = numInitialNFTs + i + 1;
        }
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
    }

    function testFail_swapTokenForSingleAnyNFTSlippage() public {
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(1);
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
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(1);
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
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 sellAmount;
        (, , , sellAmount, , , ) = pair.getSellNFTQuote(1);
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
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({
            pair: pair,
            numItems: test721.balanceOf(address(pair)) + 1
        });
        uint256 inputAmount;
        (, , , inputAmount, , , ) = pair.getBuyNFTQuote(
            test721.balanceOf(address(pair)) + 1
        );
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
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        uint256 sellAmount;
        (, , , sellAmount, , , ) = pair.getSellNFTQuote(1);
        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }

    /**
     * Test royalty fee buy
     */
    function test_buyNFTRoyaltyFee() public {
        // Setup royalty
        royaltyManager = setupRoyaltyManager(factory, address(pair.nft()), royaltyFeeMultiplier, royaltyFeeRecipient);
        factory.setRoyaltyManager(royaltyManager);

        // Create a pair with a spot price of 1 eth, 1 NFTs, no price increases, and pair fee
        uint128 delta = 0 ether;
        uint128 spotPrice = 1 ether;
        uint256[] memory idList = new uint256[](1);
        uint256 tokenId = 999;
        test721.mint(address(this), tokenId);
        idList[0] = tokenId;
        pair = this.setupPair{value: modifyInputAmount(0)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            BeaconAmmV1Pair.PoolType.TRADE,
            modifyDelta(uint64(delta)),
            pairFee,
            spotPrice,
            idList,
            0,
            address(router)
        );

        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: pair, numItems: 1});
        uint256 inputAmount;
        uint256 protocolFee;
        uint256 tradeFee;
        uint256 royaltyFee;
        (, , , inputAmount, protocolFee, tradeFee, royaltyFee) = pair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );

        // royalty recipient should have royalty amount
        address royaltyRecipient = royaltyManager.getFeeRecipient(address(pair.nft()));
        assertEq(getBalance(address(royaltyRecipient)), royaltyFee);
        // pair should have inputAmount - royaltyFee - protocolFee
        assertEq(getBalance(address(pair)), inputAmount - royaltyFee - protocolFee);
    }
}
