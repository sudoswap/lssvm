// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {LinearCurve} from "../bonding-curves/LinearCurve.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import {LSSVMPairFactory} from "../LSSVMPairFactory.sol";
import {LSSVMPair} from "../LSSVMPair.sol";
import {LSSVMRouter} from "../LSSVMRouter.sol";
import {Test721} from "../mocks/Test721.sol";
import {Test721Enumerable} from "../mocks/Test721Enumerable.sol";
import {Hevm} from "./utils/Hevm.sol";

// Tests for best-case assuming 0% fee, 0 delta linearCurve, and 0% protocol fee
contract LSSVMRouterEnumerableTest is DSTest, ERC721Holder {
    Test721Enumerable test721;
    LinearCurve linearCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;
    LSSVMPair pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;

  
    function setUp() public {
        // create contracts
        linearCurve = new LinearCurve();
        LSSVMPair pairTemplate = new LSSVMPair();
        router = new LSSVMRouter();
        test721 = new Test721Enumerable();
        factory = new LSSVMPairFactory(
            pairTemplate,
            feeRecipient,
            protocolFeeMultiplier
        );
        factory.setBondingCurveAllowed(linearCurve, true);
        factory.setRouterAllowed(router, true);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // create pair
        uint256 delta = 0.1 ether;
        uint256 fee = 5e15;
        uint256 spotPrice = 1 ether;
        uint256 numInitialNFTs = 10;
        uint256[] memory idList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
            idList[i - 1] = i;
        }
        pair = factory.createPair{value: 120 ether}(
            test721,
            linearCurve,
            LSSVMPair.PoolType.TRADE,
            delta,
            fee,
            spotPrice,
            idList
        );

        // mint extra NFTs to this contract
        for (uint256 i = numInitialNFTs + 1; i <= 3 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }

    function test_swapETHForSingleAnyNFT() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 1});
        router.swapETHForAnyNFTs{value: 1.11 ether}(
            swapList,
            2 ether,
            payable(address(this)),
            address(this),
            block.timestamp
        );
    }

    function test_swapETHForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapETHForSpecificNFTs{value: 1.11 ether}(
            swapList,
            2 ether,
            payable(address(this)),
            address(this),
            block.timestamp
        );
    }

    function test_swapSingleNFTForETH() public {
        uint256 numInitialNFTs = 10;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });

        router.swapNFTsForETH(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
    }

    function test_swapSingleNFTForAnyNFT() public {
        uint256 numInitialNFTs = 10;

        // construct NFT to ETH swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory nftToETHSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        nftToETHSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct ETH to NFT swap list
        LSSVMRouter.PairSwapAny[]
            memory ethToNFTSwapList = new LSSVMRouter.PairSwapAny[](1);
        ethToNFTSwapList[0] = LSSVMRouter.PairSwapAny({
            pair: pair,
            numItems: 1
        });

        router.swapNFTsForAnyNFTs{value: 1 ether}(
            LSSVMRouter.NFTsForAnyNFTsTrade({
                nftToETHTrades: nftToETHSwapList,
                ethToNFTTrades: ethToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp
        );
    }

    function test_swapSingleNFTForSpecificNFT() public {
        uint256 numInitialNFTs = 10;

        // construct NFT to ETH swap list
        uint256[] memory sellNFTIds = new uint256[](1);
        sellNFTIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory nftToETHSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        nftToETHSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: sellNFTIds
        });

        // construct ETH to NFT swap list
        uint256[] memory buyNFTIds = new uint256[](1);
        buyNFTIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory ethToNFTSwapList = new LSSVMRouter.PairSwapSpecific[](1);
        ethToNFTSwapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: buyNFTIds
        });

        router.swapNFTsForSpecificNFTs{value: 1 ether}(
            LSSVMRouter.NFTsForSpecificNFTsTrade({
                nftToETHTrades: nftToETHSwapList,
                ethToNFTTrades: ethToNFTSwapList
            }),
            0,
            payable(address(this)),
            address(this),
            block.timestamp
        );
    }

    function test_swapETHfor5NFTs() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        router.swapETHForAnyNFTs{value: 7 ether}(
            swapList,
            7 ether,
            payable(address(this)),
            address(this),
            block.timestamp
        );
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");
    }

    receive() external payable {}
}
