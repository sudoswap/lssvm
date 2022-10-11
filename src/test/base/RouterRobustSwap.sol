// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {BaseRouterRobustSwap} from "./BaseRouterRobustSwap.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
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

abstract contract RouterRobustSwap is DSTest, BaseRouterRobustSwap {
    // Test where pair 1 and pair 2 swap tokens for NFT succeed but pair 3 fails
    function test_robustSwapTokenForAny2NFTs() public {
        LSSVMRouter.RobustPairSwapAny[]
            memory swapList = new LSSVMRouter.RobustPairSwapAny[](3);
        swapList[0] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: pair1, numItems: 2}),
            maxCost: 0.44 ether
        });
        swapList[1] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: pair2, numItems: 2}),
            maxCost: 0.44 ether
        });
        swapList[2] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: pair3, numItems: 2}),
            maxCost: 0.44 ether
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the first two swapPairs succeed, and the last one silently fail
        // with 10% protocol fee:
        // the first swapPair costs 0.22 tokens
        // the second swapPair costs 0.44 tokens
        // the third swapPair costs 0.66 tokens
        uint256 remainingValue = this.robustSwapTokenForAnyNFTs{
            value: modifyInputAmount(1.32 ether)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            1.32 ether
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        // If the first two swap pairs succeed, we pay 0.6 tokens and gain 4 NFTs
        require(
            (afterNFTBalance - beforeNFTBalance) == 4,
            "Incorrect NFT swap"
        );
        require(remainingValue == 0.66 ether, "Incorrect refund");
    }

    // Test where pair 1 and pair 2 swap tokens for NFT succeed but pair 3 fails
    function test_robustSwapTokenFor2SpecificNFTs() public {
        uint256[] memory nftIds1 = new uint256[](2);
        nftIds1[0] = 0;
        nftIds1[1] = 1;

        uint256[] memory nftIds2 = new uint256[](2);
        nftIds2[0] = 10;
        nftIds2[1] = 11;

        uint256[] memory nftIds3 = new uint256[](2);
        nftIds3[0] = 20;
        nftIds3[1] = 21;

        LSSVMRouter.RobustPairSwapSpecific[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecific[](3);
        swapList[0] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            maxCost: 0.44 ether
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            maxCost: 0.44 ether
        });
        swapList[2] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair3,
                nftIds: nftIds3
            }),
            maxCost: 0.44 ether
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the first two swapPairs succeed, and the last one silently fail
        // with 10% protocol fee:
        // the first swapPair costs 0.22 ETH
        // the second swapPair costs 0.44 ETH
        // the third swapPair costs 0.66 ETH
        uint256 remainingValue = this.robustSwapTokenForSpecificNFTs{
            value: modifyInputAmount(1.32 ether)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            1.32 ether
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        // If the first two swap pairs succeed, we pay 0.6 eth and gain 4 NFTs
        require(
            (afterNFTBalance - beforeNFTBalance) == 4,
            "Incorrect NFT swap"
        );
        require(remainingValue == 0.66 ether, "Incorrect ETH refund");
    }

    // Test where selling to pair 2 and pair 3 succeeds, but selling to pair 1 fails
    function test_robustSwap2NFTsForToken() public {
        uint256[] memory nftIds1 = new uint256[](2);
        nftIds1[0] = 30;
        nftIds1[1] = 31;

        uint256[] memory nftIds2 = new uint256[](2);
        nftIds2[0] = 32;
        nftIds2[1] = 33;

        uint256[] memory nftIds3 = new uint256[](2);
        nftIds3[0] = 34;
        nftIds3[1] = 35;

        LSSVMRouter.RobustPairSwapSpecificForToken[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecificForToken[](
                3
            );
        swapList[0] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            minOutput: 0.3 ether
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            minOutput: 0.3 ether
        });
        swapList[2] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair3,
                nftIds: nftIds3
            }),
            minOutput: 0.3 ether
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the last two swapPairs succeed, and the first one silently fail
        // with 10% protocol fee:
        // the first swapPair gives 0.18 ETH
        // the second swapPair gives 0.36 ETH
        // the third swapPair gives 0.54 ETH
        uint256 remainingValue = router.robustSwapNFTsForToken(
            swapList,
            payable(address(this)),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        require(
            (beforeNFTBalance - afterNFTBalance) == 4,
            "Incorrect NFT swap"
        );
        require(remainingValue == 0.9 ether, "Incorrect ETH received");
    }

    // Test where selling to pair 2 succeeds,
    // but selling to pair 1 fails due to slippage
    // and selling to pair 3 fails due to a bonding curve error
    function test_robustSwapNFTsForTokenWithBondingCurveError() public {
        uint256[] memory nftIds1 = new uint256[](2);
        nftIds1[0] = 30;
        nftIds1[1] = 31;

        uint256[] memory nftIds2 = new uint256[](2);
        nftIds2[0] = 32;
        nftIds2[1] = 33;

        uint256[] memory nftIds3 = new uint256[](0);

        LSSVMRouter.RobustPairSwapSpecificForToken[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecificForToken[](
                3
            );
        swapList[0] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            minOutput: 0.3 ether
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            minOutput: 0.3 ether
        });
        swapList[2] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair3,
                nftIds: nftIds3
            }),
            minOutput: 0.3 ether
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the last two swapPairs succeed, and the first one silently fail
        // with 10% protocol fee:
        // the first swapPair gives 0.18 ETH
        // the second swapPair gives 0.36 ETH
        // the third swapPair gives 0.54 ETH
        uint256 remainingValue = router.robustSwapNFTsForToken(
            swapList,
            payable(address(this)),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        require(
            (beforeNFTBalance - afterNFTBalance) == 2,
            "Incorrect NFT swap"
        );
        require(remainingValue == 0.36 ether, "Incorrect ETH received");
    }

    // Test where we buy and sell in the same tx
    function test_robustSwapNFTsForTokenAndTokenForNFTs() public {
        // Check that we own #0 and #1, and that we don't own #32 and #33
        assertEq(test721.ownerOf(0), address(pair1));
        assertEq(test721.ownerOf(1), address(pair1));
        assertEq(test721.ownerOf(32), address(this));
        assertEq(test721.ownerOf(33), address(this));

        uint256[] memory nftIds1 = new uint256[](2);
        nftIds1[0] = 0;
        nftIds1[1] = 1;
        LSSVMRouter.RobustPairSwapSpecific[]
            memory tokenToNFTSwapList = new LSSVMRouter.RobustPairSwapSpecific[](
                1
            );
        tokenToNFTSwapList[0] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            maxCost: 0.44 ether
        });

        // We queue up a NFT->Token swap that should work
        uint256[] memory nftIds2 = new uint256[](2);
        nftIds2[0] = 32;
        nftIds2[1] = 33;
        LSSVMRouter.RobustPairSwapSpecificForToken[]
            memory nftToTokenSwapList = new LSSVMRouter.RobustPairSwapSpecificForToken[](
                1
            );
        nftToTokenSwapList[0] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            minOutput: 0.3 ether
        });

        // Do the swap
        uint256 inputAmount = 0.44 ether;
        this.robustSwapTokenForSpecificNFTsAndNFTsForTokens{
            value: modifyInputAmount(inputAmount)
        }(
            router,
            LSSVMRouter.RobustPairNFTsFoTokenAndTokenforNFTsTrade({
                nftToTokenTrades: nftToTokenSwapList,
                tokenToNFTTrades: tokenToNFTSwapList,
                inputAmount: inputAmount,
                tokenRecipient: payable(address(this)),
                nftRecipient: address(this)
            })
        );

        // Check that we own #0 and #1, and that we don't own #32 and #33
        assertEq(test721.ownerOf(0), address(this));
        assertEq(test721.ownerOf(1), address(this));
        assertEq(test721.ownerOf(32), address(pair2));
        assertEq(test721.ownerOf(33), address(pair2));
    }
}
