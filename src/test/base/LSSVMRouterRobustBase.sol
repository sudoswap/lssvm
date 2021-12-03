// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairEnumerable} from "../../LSSVMPairEnumerable.sol";
import {LSSVMPairMissingEnumerable} from "../../LSSVMPairMissingEnumerable.sol";
import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {IERC721Mintable} from "../../test/IERC721Mintable.sol";
import {Hevm} from "../utils/Hevm.sol";

abstract contract LSSVMRouterRobustBaseTest is DSTest, ERC721Holder {
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
        LSSVMPair enumerableTemplate = new LSSVMPairEnumerable();
        LSSVMPair missingEnumerableTemplate = new LSSVMPairMissingEnumerable();
        factory = new LSSVMPairFactory(
            enumerableTemplate,
            missingEnumerableTemplate,
            feeRecipient,
            protocolFeeMultiplier
        );
        router = new LSSVMRouter();

        // Set approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        uint256[] memory empty;
        uint256 nftIndex = 0;

        // Create 3 pairs with 0 delta and 0 trade fee
        // pair 1 has spot price of 0.1 ETH, then pair 2 has 0.2 ETH, and pair 3 has 0.3 ETH
        // Send 10 NFTs to each pair
        // (0-9), (10-19), (20-29)
        pair1 = factory.createPair{value: 10 ether}(
            test721,
            bondingCurve,
            LSSVMPair.PoolType.TRADE,
            0,
            0,
            0.1 ether,
            empty
        );
        for (uint256 j = 0; j < 10; j++) {
            test721.mint(address(this), nftIndex);
            test721.safeTransferFrom(address(this), address(pair1), nftIndex);
            nftIndex++;
        }

        pair2 = factory.createPair{value: 10 ether}(
            test721,
            bondingCurve,
            LSSVMPair.PoolType.TRADE,
            0,
            0,
            0.2 ether,
            empty
        );
        for (uint256 j = 0; j < 10; j++) {
            test721.mint(address(this), nftIndex);
            test721.safeTransferFrom(address(this), address(pair2), nftIndex);
            nftIndex++;
        }

        pair3 = factory.createPair{value: 10 ether}(
            test721,
            bondingCurve,
            LSSVMPair.PoolType.TRADE,
            0,
            0,
            0.3 ether,
            empty
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

    // Test where pair 1 and pair 2 swap ETH for NFT succeed but pair 3 fails
    function test_robustSwapETHForAnyNFTs() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](3);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair1, numItems: 2});
        swapList[1] = LSSVMRouter.PairSwapAny({pair: pair2, numItems: 2});
        swapList[2] = LSSVMRouter.PairSwapAny({pair: pair3, numItems: 2});

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        uint256[] memory maxCostPerNFTSwap = new uint256[](3);
        maxCostPerNFTSwap[0] = 0.44 ether;
        maxCostPerNFTSwap[1] = 0.44 ether;
        maxCostPerNFTSwap[2] = 0.44 ether;

        // Expect to have the first two swapPairs succeed, and the last one silently fail
        // with 10% protocol fee:
        // the first swapPair costs 0.22 ETH
        // the second swapPair costs 0.44 ETH
        // the third swapPair costs 0.66 ETH
        uint256 remainingValue = router.robustSwapETHForAnyNFTs{
            value: 1.32 ether
        }(
            swapList,
            maxCostPerNFTSwap,
            payable(address(this)),
            address(this),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        // If the first two swap pairs succeed, we pay 0.6 eth and gain 4 NFTs
        require(
            (afterNFTBalance - beforeNFTBalance) == 4,
            "Incorrect NFT swap"
        );
        require(remainingValue == 0.66 ether, "Incorrect ETH refund");
    }

    /*
    // Test where pair 1 and pair 2 swap ETH for NFT succeed but pair 3 fails
    function test_robustSwapETHForSpecificNFTs() public {
        
        uint256[] memory nftIds1 = new uint256[](2);
        nftIds1[0] = 0;
        nftIds1[1] = 1;
        
        uint256[] memory nftIds2 = new uint256[](2);
        nftIds2[0] = 10;
        nftIds2[1] = 11;
        

        uint256[] memory nftIds3 = new uint256[](2);
        nftIds3[0] = 20;
        nftIds3[1] = 21;

        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](3);
        swapList[0] = LSSVMRouter.PairSwapSpecific({pair: pair1, nftIds: nftIds1});
        swapList[1] = LSSVMRouter.PairSwapSpecific({pair: pair2, nftIds: nftIds2});
        swapList[2] = LSSVMRouter.PairSwapSpecific({pair: pair3, nftIds: nftIds3});
        
        uint256[] memory maxCostPerNFTSwap = new uint256[](3);
        maxCostPerNFTSwap[0] = 0.44 ether;
        maxCostPerNFTSwap[1] = 0.44 ether;
        maxCostPerNFTSwap[2] = 0.44 ether;

        uint256 beforeNFTBalance = test721.balanceOf(address(this));

        // Expect to have the first two swapPairs succeed, and the last one silently fail 
        // with 10% protocol fee: 
        // the first swapPair costs 0.22 ETH
        // the second swapPair costs 0.44 ETH
        // the third swapPair costs 0.66 ETH 
        uint256 remainingValue = router.robustSwapETHForSpecificNFTs{value: 1.32 ether}(
            swapList,
            maxCostPerNFTSwap,
            payable(address(this)),
            address(this),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        // If the first two swap pairs succeed, we pay 0.6 eth and gain 4 NFTs
        require((afterNFTBalance-beforeNFTBalance) == 4, "Incorrect NFT swap");
        require(remainingValue == 0.66 ether, "Incorrect ETH refund");
    }

    // Test where selling to pair 2 and pair 3 succeeds, but selling to pair 1 fails
    function test_robustSwapNFTsforETH() public {

        uint256[] memory nftIds1 = new uint256[](2);
        nftIds1[0] = 30;
        nftIds1[1] = 31;
        
        uint256[] memory nftIds2 = new uint256[](2);
        nftIds2[0] = 32;
        nftIds2[1] = 33;
        

        uint256[] memory nftIds3 = new uint256[](2);
        nftIds3[0] = 34;
        nftIds3[1] = 35;

        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](3);
        swapList[0] = LSSVMRouter.PairSwapSpecific({pair: pair1, nftIds: nftIds1});
        swapList[1] = LSSVMRouter.PairSwapSpecific({pair: pair2, nftIds: nftIds2});
        swapList[2] = LSSVMRouter.PairSwapSpecific({pair: pair3, nftIds: nftIds3});

        uint256 beforeNFTBalance = test721.balanceOf(address(this));
        
        uint256[] memory minOutputPerSwapPair = new uint256[](3);
        minOutputPerSwapPair[0] = 0.3 ether;
        minOutputPerSwapPair[1] = 0.3 ether;
        minOutputPerSwapPair[2] = 0.3 ether;

        // Expect to have the last two swapPairs succeed, and the first one silently fail 
        // with 10% protocol fee: 
        // the first swapPair gives 0.18 ETH
        // the second swapPair gives 0.36 ETH
        // the third swapPair gives 0.54 ETH 
        uint256 remainingValue = router.robustSwapNFTsForETH(
            swapList,
            minOutputPerSwapPair,
            payable(address(this)),
            block.timestamp
        );

        uint256 afterNFTBalance = test721.balanceOf(address(this));

        require((beforeNFTBalance-afterNFTBalance) == 4, "Incorrect NFT swap");
        require(remainingValue == 0.9 ether, "Incorrect ETH received");
    }
    */

    receive() external payable {}

    function setupCurve() public virtual returns (ICurve);

    function setup721() public virtual returns (IERC721Mintable);
}
