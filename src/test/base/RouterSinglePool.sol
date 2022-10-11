// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {BaseRouterSinglePool} from "./BaseRouterSinglePool.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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

abstract contract RouterSinglePool is DSTest, BaseRouterSinglePool {
    function test_swapTokenForSingleAnyNFT() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 1});
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
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
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
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
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
            LSSVMRouter.PairSwapSpecific[]
                memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
            swapList[0] = LSSVMRouter.PairSwapSpecific({
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
        LSSVMRouter.PairSwapSpecific[]
            memory nftToTokenSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct Token to NFT swap list
        LSSVMRouter.PairSwapAny[]
            memory tokenToNFTSwapList = new LSSVMRouter.PairSwapAny[](1);
        tokenToNFTSwapList[0] = LSSVMRouter.PairSwapAny({
            pair: pair,
            numItems: 1
        });

        // NOTE: We send some tokens (more than enough) to cover the protocol fee needed
        uint256 inputAmount = 0.01 ether;
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
    }

    function test_swapSingleNFTForSpecificNFT() public {
        // construct NFT to token swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory nftToTokenSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        nftToTokenSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct token to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory tokenToNFTSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        tokenToNFTSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: buyNFTIds
        });

        // NOTE: We send some tokens (more than enough) to cover the protocol fee
        uint256 inputAmount = 0.01 ether;
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
    }

    function test_swapTokenforAny5NFTs() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 5});
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
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
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
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 1});
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
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
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
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
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
        sellAmount = sellAmount + 1 wei;
        router.swapNFTsForToken(
            swapList,
            sellAmount,
            payable(address(this)),
            block.timestamp
        );
    }
}
