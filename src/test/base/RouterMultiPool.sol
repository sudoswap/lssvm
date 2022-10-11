// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {BaseRouterMultiPool} from "./BaseRouterMultiPool.sol";

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

// Gives more realistic scenarios where swaps have to go through multiple pools, for more accurate gas profiling
abstract contract RouterMultiPool is DSTest, BaseRouterMultiPool {
    function test_swapTokenForAny5NFTs() public {
        // Swap across all 5 pools
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](5);
        uint256 totalInputAmount = 0;
        for (uint256 i = 0; i < 5; i++) {
            uint256 inputAmount;
            (, , , inputAmount, ) = pairs[i + 1].getBuyNFTQuote(1);
            totalInputAmount += inputAmount;
            swapList[i] = LSSVMRouter.PairSwapAny({
                pair: pairs[i + 1],
                numItems: 1
            });
        }
        uint256 startBalance = test721.balanceOf(address(this));
        this.swapTokenForAnyNFTs{value: modifyInputAmount(totalInputAmount)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            totalInputAmount
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");
    }

    function test_swapTokenForSpecific5NFTs() public {
        // Swap across all 5 pools
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](5);
        uint256 totalInputAmount = 0;
        for (uint256 i = 0; i < 5; i++) {
            uint256 inputAmount;
            (, , , inputAmount, ) = pairs[i + 1].getBuyNFTQuote(1);
            totalInputAmount += inputAmount;
            uint256[] memory nftIds = new uint256[](1);
            nftIds[0] = i + 1;
            swapList[i] = LSSVMRouter.PairSwapSpecific({
                pair: pairs[i + 1],
                nftIds: nftIds
            });
        }
        uint256 startBalance = test721.balanceOf(address(this));
        this.swapTokenForSpecificNFTs{
            value: modifyInputAmount(totalInputAmount)
        }(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            totalInputAmount
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");
    }

    function test_swap5NFTsForToken() public {
        // Swap across all 5 pools
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](5);
        uint256 totalOutputAmount = 0;
        for (uint256 i = 0; i < 5; i++) {
            uint256 outputAmount;
            (, , , outputAmount, ) = pairs[i + 1].getSellNFTQuote(1);
            totalOutputAmount += outputAmount;
            uint256[] memory nftIds = new uint256[](1);
            // Set it to be an ID we own
            nftIds[0] = i + 6;
            swapList[i] = LSSVMRouter.PairSwapSpecific({
                pair: pairs[i + 1],
                nftIds: nftIds
            });
        }
        uint256 startBalance = test721.balanceOf(address(this));
        router.swapNFTsForToken(
            swapList,
            totalOutputAmount,
            payable(address(this)),
            block.timestamp
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((startBalance - endBalance) == 5, "Too few NFTs sold");
    }
}
