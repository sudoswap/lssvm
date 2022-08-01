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

abstract contract RouterRobustSwap is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;

    // Create 3 pairs
    LSSVMPair pair1;
    LSSVMPair pair2;
    LSSVMPair pair3;

    address payable constant feeRecipient = payable(address(69));

    // Set protocol fee to be 10%
    uint256 constant protocolFeeMultiplier = 1e17;

    function setUp() public {
        // Create contracts
        bondingCurve = setupCurve();
        test721 = setup721();
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
        router = new LSSVMRouter(factory);

        // Set approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        uint256[] memory empty;
        uint256 nftIndex = 0;

        // Create 3 pairs with 0 delta and 0 trade fee
        // pair 1 has spot price of 0.1 TOKEN, then pair 2 has 0.2 TOKEN, and pair 3 has 0.3 TOKEN
        // Send 10 NFTs to each pair
        // (0-9), (10-19), (20-29)
        pair1 = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            modifyDelta(0),
            0,
            0.1 ether,
            empty,
            10 ether,
            address(router)
        );
        for (uint256 j = 0; j < 10; j++) {
            test721.mint(address(this), nftIndex);
            test721.safeTransferFrom(address(this), address(pair1), nftIndex);
            nftIndex++;
        }

        pair2 = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            modifyDelta(0),
            0,
            0.2 ether,
            empty,
            10 ether,
            address(router)
        );
        for (uint256 j = 0; j < 10; j++) {
            test721.mint(address(this), nftIndex);
            test721.safeTransferFrom(address(this), address(pair2), nftIndex);
            nftIndex++;
        }

        pair3 = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            modifyDelta(0),
            0,
            0.3 ether,
            empty,
            10 ether,
            address(router)
        );
        for (uint256 j = 0; j < 10; j++) {
            test721.mint(address(this), nftIndex);
            test721.safeTransferFrom(address(this), address(pair3), nftIndex);
            nftIndex++;
        }

        // Mint NFTs 30-39 to this contract
        for (uint256 i = 0; i < 10; i++) {
            test721.mint(address(this), nftIndex);
            nftIndex++;
        }
    }

    // Test where pair 1 and pair 2 swap tokens for NFT succeed but pair 3 fails
    function test_robustSwapTokenForAny2NFTs() public {
        LSSVMRouter.RobustPairSwapAny[]
            memory swapList = new LSSVMRouter.RobustPairSwapAny[](3);

        (, , , uint256 pair1InputAmount, ) = pair1.getBuyNFTQuote(2);
        (, , , uint256 pair2InputAmount, ) = pair2.getBuyNFTQuote(2);

        swapList[0] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: pair1, numItems: 2}),
            maxCost: pair2InputAmount
        });
        swapList[1] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: pair2, numItems: 2}),
            maxCost: pair2InputAmount
        });
        swapList[2] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: pair3, numItems: 2}),
            maxCost: pair2InputAmount
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the first two swapPairs succeed, and the last one silently fail
        // with 10% protocol fee:
        uint256 remainingValue = this.robustSwapTokenForAnyNFTs{
            value: modifyInputAmount(pair2InputAmount * 3)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            pair2InputAmount * 3
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        // If the first two swap pairs succeed, we gain 4 NFTs
        assertEq((afterNFTBalance - beforeNFTBalance), 4, "Incorrect NFT swap");

        assertEq(
            remainingValue,
            pair2InputAmount * 3 - (pair1InputAmount + pair2InputAmount),
            "Incorrect refund"
        );
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

        (, , , uint256 pair1InputAmount, ) = pair1.getBuyNFTQuote(2);
        (, , , uint256 pair2InputAmount, ) = pair2.getBuyNFTQuote(2);

        LSSVMRouter.RobustPairSwapSpecific[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecific[](3);
        swapList[0] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            maxCost: pair2InputAmount
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            maxCost: pair2InputAmount
        });
        swapList[2] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair3,
                nftIds: nftIds3
            }),
            maxCost: pair2InputAmount
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the first two swapPairs succeed, and the last one silently fail
        // with 10% protocol fee:
        uint256 remainingValue = this.robustSwapTokenForSpecificNFTs{
            value: modifyInputAmount(pair2InputAmount * 3)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            pair2InputAmount * 3
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        // If the first two swap pairs succeed we gain 4 NFTs
        assertEq((afterNFTBalance - beforeNFTBalance), 4, "Incorrect NFT swap");
        assertEq(
            remainingValue,
            pair2InputAmount * 3 - (pair1InputAmount + pair2InputAmount),
            "Incorrect ETH refund"
        );
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

        (, , , uint256 pair2OutputAmount, ) = pair2.getSellNFTQuote(2);
        (, , , uint256 pair3OutputAmount, ) = pair3.getSellNFTQuote(2);

        LSSVMRouter.RobustPairSwapSpecificForToken[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecificForToken[](
                3
            );
        swapList[0] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            minOutput: pair2OutputAmount
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            minOutput: pair2OutputAmount
        });
        swapList[2] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair3,
                nftIds: nftIds3
            }),
            minOutput: pair2OutputAmount
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the last two swapPairs succeed, and the first one silently fail
        // with 10% protocol fee:
        uint256 remainingValue = router.robustSwapNFTsForToken(
            swapList,
            payable(address(this)),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        assertEq((beforeNFTBalance - afterNFTBalance), 4, "Incorrect NFT swap");
        assertEq(
            remainingValue,
            pair3OutputAmount + pair2OutputAmount,
            "Incorrect ETH received"
        );
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

        (, , , uint256 pair2OutputAmount, ) = pair2.getSellNFTQuote(2);

        LSSVMRouter.RobustPairSwapSpecificForToken[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecificForToken[](
                3
            );
        swapList[0] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair1,
                nftIds: nftIds1
            }),
            minOutput: pair2OutputAmount
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair2,
                nftIds: nftIds2
            }),
            minOutput: pair2OutputAmount
        });
        swapList[2] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: pair3,
                nftIds: nftIds3
            }),
            minOutput: pair2OutputAmount
        });

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the last two swapPairs succeed, and the first one silently fail
        // with 10% protocol fee:
        uint256 remainingValue = router.robustSwapNFTsForToken(
            swapList,
            payable(address(this)),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        assertEq((beforeNFTBalance - afterNFTBalance), 2, "Incorrect NFT swap");
        assertEq(remainingValue, pair2OutputAmount, "Incorrect ETH received");
    }

    // Test where we buy and sell in the same tx
    function test_robustSwapNFTsForTokenAndTokenForNFTs() public {
        // Check that we own #0 and #1, and that we don't own #32 and #33
        assertEq(test721.ownerOf(0), address(pair1));
        assertEq(test721.ownerOf(1), address(pair1));
        assertEq(test721.ownerOf(32), address(this));
        assertEq(test721.ownerOf(33), address(this));

        (, , , uint256 pair1InputAmount, ) = pair1.getBuyNFTQuote(2);
        (, , , uint256 pair2OutputAmount, ) = pair2.getSellNFTQuote(2);

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
            maxCost: pair1InputAmount
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
            minOutput: pair2OutputAmount
        });

        // Do the swap
        uint256 inputAmount = pair1InputAmount;
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
