// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ICurve} from "../../bonding-curves/ICurve.sol";
import {BeaconAmmV1PairFactory} from "../../BeaconAmmV1PairFactory.sol";
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

abstract contract RouterSinglePoolWithAssetRecipient is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    BeaconAmmV1PairFactory factory;
    BeaconAmmV1Router router;
    BeaconAmmV1Pair sellPair; // Gives NFTs, takes in tokens
    BeaconAmmV1Pair buyPair; // Takes in NFTs, gives tokens
    address payable constant feeRecipient = payable(address(69));
    address payable constant sellPairRecipient = payable(address(1));
    address payable constant buyPairRecipient = payable(address(2));
    uint256 constant protocolFeeMultiplier = 0;
    uint256 constant numInitialNFTs = 10;

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
        uint256[] memory sellIDList = new uint256[](numInitialNFTs);
        uint256[] memory buyIDList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= 2 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
            if (i <= numInitialNFTs) {
                sellIDList[i - 1] = i;
            } else {
                buyIDList[i - numInitialNFTs - 1] = i;
            }
        }

        // Create a sell pool with a spot price of 1 eth, 10 NFTs, and no price increases
        // All stuff gets sent to assetRecipient
        sellPair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            BeaconAmmV1Pair.PoolType.NFT,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            sellIDList,
            10 ether,
            address(router)
        );

        // Create a buy pool with a spot price of 1 eth, 10 NFTs, and no price increases
        // All stuff gets sent to assetRecipient
        buyPair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            BeaconAmmV1Pair.PoolType.TOKEN,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            buyIDList,
            10 ether,
            address(router)
        );

        // mint extra NFTs to this contract (i.e. to be held by the caller)
        for (uint256 i = 2 * numInitialNFTs + 1; i <= 3 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }

    function test_swapTokenForSingleAnyNFT() public {
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: sellPair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, , , ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swapTokenForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, , , ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swapSingleNFTForToken() public {
        uint256 beforeBuyPairNFTBalance = test721.balanceOf(address(buyPair));
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs * 2 + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
        assertEq(test721.balanceOf(buyPairRecipient), 1);
        // Pool should still keep track of the same number of NFTs prior to the swap
        // because we sent the NFT to the asset recipient (and not the pair)
        uint256 afterBuyPairNFTBalance = (buyPair.getAllHeldIds()).length;
        assertEq(beforeBuyPairNFTBalance, afterBuyPairNFTBalance);
    }

    function test_swapSingleNFTForAnyNFT() public {
        // construct NFT to Token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = 2 * numInitialNFTs + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: sellNFTIds
        });
        // construct Token to NFT swap list
        BeaconAmmV1Router.PairSwapAny[]
            memory tokenToNFTSwapList = new BeaconAmmV1Router.PairSwapAny[](1);
        tokenToNFTSwapList[0] = BeaconAmmV1Router.PairSwapAny({
            pair: sellPair,
            numItems: 1
        });
        uint256 sellAmount;
        (, , , sellAmount, , , ) = sellPair.getBuyNFTQuote(1);
        // Note: we send a little bit of tokens with the call because the exponential curve increases price ever so slightly
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
        assertEq(test721.balanceOf(buyPairRecipient), 1);
        assertEq(getBalance(sellPairRecipient), sellAmount);
    }

    function test_swapSingleNFTForSpecificNFT() public {
        // construct NFT to token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = 2 * numInitialNFTs + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory nftToTokenSwapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: sellNFTIds
        });

        // construct token to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = numInitialNFTs;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory tokenToNFTSwapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        tokenToNFTSwapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: buyNFTIds
        });
        uint256 sellAmount;
        (, , , sellAmount, , , ) = sellPair.getBuyNFTQuote(1);
        // Note: we send a little bit of tokens with the call because the exponential curve increases price ever so slightly
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
        assertEq(test721.balanceOf(buyPairRecipient), 1);
        assertEq(getBalance(sellPairRecipient), sellAmount);
    }

    function test_swapTokenforAny5NFTs() public {
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: sellPair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, , , ) = sellPair.getBuyNFTQuote(5);
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
        assertEq(getBalance(sellPairRecipient), inputAmount);
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
            pair: sellPair,
            nftIds: nftIds
        });
        uint256 startBalance = test721.balanceOf(address(this));
        uint256 inputAmount;
        (, , , inputAmount, , , ) = sellPair.getBuyNFTQuote(5);
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
        assertEq(getBalance(sellPairRecipient), inputAmount);
    }

    function test_swap5NFTsForToken() public {
        uint256 beforeBuyPairNFTBalance = test721.balanceOf(address(buyPair));
        uint256[] memory nftIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nftIds[i] = 2 * numInitialNFTs + i + 1;
        }
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
        assertEq(test721.balanceOf(buyPairRecipient), 5);
        // Pool should still keep track of the same number of NFTs prior to the swap
        // because we sent the NFT to the asset recipient (and not the pair)
        uint256 afterBuyPairNFTBalance = (buyPair.getAllHeldIds()).length;
        assertEq(beforeBuyPairNFTBalance, afterBuyPairNFTBalance);
    }

    function test_swapSingleNFTForTokenWithProtocolFee() public {
        // Set protocol fee to be 10%
        factory.changeProtocolFeeMultiplier(0.1e18);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs * 2 + 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: buyPair,
            nftIds: nftIds
        });
        uint256 output = router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
        // User gets 90% of the tokens (which is output) and the other 10% goes to the factory
        assertEq(getBalance(address(factory)), output / 9);
    }

    function test_swapTokenForSingleSpecificNFTWithProtocolFee() public {
        // Set protocol fee to be 10%
        factory.changeProtocolFeeMultiplier(0.1e18);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        BeaconAmmV1Router.PairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.PairSwapSpecific[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapSpecific({
            pair: sellPair,
            nftIds: nftIds
        });
        uint256 inputAmount;
        (, , , inputAmount, , , ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        // Assert 90% and 10% split of the buy amount between sellPairRecipient and the factory
        assertEq(getBalance(address(factory)), inputAmount / 11);
        assertEq(
            getBalance(sellPairRecipient) + getBalance(address(factory)),
            inputAmount
        );
    }

    function test_swapTokenForSingleAnyNFTWithProtocolFee() public {
        // Set protocol fee to be 10%
        factory.changeProtocolFeeMultiplier(0.1e18);
        BeaconAmmV1Router.PairSwapAny[]
            memory swapList = new BeaconAmmV1Router.PairSwapAny[](1);
        swapList[0] = BeaconAmmV1Router.PairSwapAny({pair: sellPair, numItems: 1});
        uint256 inputAmount;
        (, , , inputAmount, , , ) = sellPair.getBuyNFTQuote(1);
        this.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            inputAmount
        );
        // Assert 90% and 10% split of the buy amount between sellPairRecipient and the factory
        assertEq(getBalance(address(factory)), inputAmount / 11);
        assertEq(
            getBalance(sellPairRecipient) + getBalance(address(factory)),
            inputAmount
        );
    }
}
