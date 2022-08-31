// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ICurve} from "../../bonding-curves/ICurve.sol";
import {BeaconAmmV1Factory} from "../../BeaconAmmV1Factory.sol";
import {BeaconAmmV1} from "../../BeaconAmmV1.sol";
import {BeaconAmmV1ETH} from "../../BeaconAmmV1ETH.sol";
import {BeaconAmmV1ERC20} from "../../BeaconAmmV1ERC20.sol";
import {BeaconAmmV1EnumerableETH} from "../../BeaconAmmV1EnumerableETH.sol";
import {BeaconAmmV1MissingEnumerableETH} from "../../BeaconAmmV1MissingEnumerableETH.sol";
import {BeaconAmmV1EnumerableERC20} from "../../BeaconAmmV1EnumerableERC20.sol";
import {BeaconAmmV1MissingEnumerableERC20} from "../../BeaconAmmV1MissingEnumerableERC20.sol";
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
    BeaconAmmV1Factory factory;
    BeaconAmmV1Router router;
    BeaconAmmV1 pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    uint256 constant numInitialNFTs = 10;

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        BeaconAmmV1EnumerableETH enumerableETHTemplate = new BeaconAmmV1EnumerableETH();
        BeaconAmmV1MissingEnumerableETH missingEnumerableETHTemplate = new BeaconAmmV1MissingEnumerableETH();
        BeaconAmmV1EnumerableERC20 enumerableERC20Template = new BeaconAmmV1EnumerableERC20();
        BeaconAmmV1MissingEnumerableERC20 missingEnumerableERC20Template = new BeaconAmmV1MissingEnumerableERC20();
        factory = new BeaconAmmV1Factory(
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
            BeaconAmmV1.PoolType.TRADE,
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(5);
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(5);
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(1);
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
        (, , , sellAmount, ) = pair.getSellNFTQuote(1);
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
        (, , , inputAmount, ) = pair.getBuyNFTQuote(
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
        (, , , sellAmount, ) = pair.getSellNFTQuote(1);
        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }
}
