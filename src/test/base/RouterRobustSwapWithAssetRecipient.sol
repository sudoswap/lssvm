// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {BaseRouterRobustSwapWithAssetRecipient} from "./BaseRouterRobustSwapWithAssetRecipient.sol";

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

abstract contract RouterRobustSwapWithAssetRecipient is
    DSTest,
    BaseRouterRobustSwapWithAssetRecipient
{
    // Swapping tokens for any NFT on sellPair1 works, but fails silently on sellPair2 if slippage is too tight
    function test_robustSwapTokenForAnyNFTs() public {
        uint256 sellPair1Price;
        (, , , sellPair1Price, ) = sellPair1.getBuyNFTQuote(1);
        LSSVMRouter.RobustPairSwapAny[]
            memory swapList = new LSSVMRouter.RobustPairSwapAny[](2);
        swapList[0] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: sellPair1, numItems: 1}),
            maxCost: sellPair1Price
        });
        swapList[1] = LSSVMRouter.RobustPairSwapAny({
            swapInfo: LSSVMRouter.PairSwapAny({pair: sellPair2, numItems: 1}),
            maxCost: 0 ether
        });
        uint256 remainingValue = this.robustSwapTokenForAnyNFTs{
            value: modifyInputAmount(2 ether)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            2 ether
        );
        assertEq(remainingValue + sellPair1Price, 2 ether);
        assertEq(getBalance(sellPairRecipient), sellPair1Price);
    }

    // Swapping tokens to a specific NFT with sellPair2 works, but fails silently on sellPair1 if slippage is too tight
    function test_robustSwapTokenForSpecificNFTs() public {
        uint256 sellPair1Price;
        (, , , sellPair1Price, ) = sellPair2.getBuyNFTQuote(1);
        LSSVMRouter.RobustPairSwapSpecific[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecific[](2);
        uint256[] memory nftIds1 = new uint256[](1);
        nftIds1[0] = 1;
        uint256[] memory nftIds2 = new uint256[](1);
        nftIds2[0] = 2;
        swapList[0] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: sellPair1,
                nftIds: nftIds1
            }),
            maxCost: 0 ether
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecific({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: sellPair2,
                nftIds: nftIds2
            }),
            maxCost: sellPair1Price
        });
        uint256 remainingValue = this.robustSwapTokenForSpecificNFTs{
            value: modifyInputAmount(2 ether)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            2 ether
        );
        assertEq(remainingValue + sellPair1Price, 2 ether);
        assertEq(getBalance(sellPairRecipient), sellPair1Price);
    }

    // Swapping NFTs to tokens with buyPair1 works, but buyPair2 silently fails due to slippage
    function test_robustSwapNFTsForToken() public {
        uint256 buyPair1Price;
        (, , , buyPair1Price, ) = buyPair1.getSellNFTQuote(1);
        uint256[] memory nftIds1 = new uint256[](1);
        nftIds1[0] = 5;
        uint256[] memory nftIds2 = new uint256[](1);
        nftIds2[0] = 6;
        LSSVMRouter.RobustPairSwapSpecificForToken[]
            memory swapList = new LSSVMRouter.RobustPairSwapSpecificForToken[](
                2
            );
        swapList[0] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: buyPair1,
                nftIds: nftIds1
            }),
            minOutput: buyPair1Price
        });
        swapList[1] = LSSVMRouter.RobustPairSwapSpecificForToken({
            swapInfo: LSSVMRouter.PairSwapSpecific({
                pair: buyPair2,
                nftIds: nftIds2
            }),
            minOutput: 2 ether
        });
        router.robustSwapNFTsForToken(
            swapList,
            payable(address(this)),
            block.timestamp
        );
        assertEq(test721.balanceOf(buyPairRecipient), 1);
    }
}
