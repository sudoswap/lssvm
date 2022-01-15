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
        LSSVMPairETH enumerableETHTemplate = new LSSVMPairEnumerableETH();
        LSSVMPairETH missingEnumerableETHTemplate = new LSSVMPairMissingEnumerableETH();
        LSSVMPairERC20 enumerableERC20Template = new LSSVMPairEnumerableERC20();
        LSSVMPairERC20 missingEnumerableERC20Template = new LSSVMPairMissingEnumerableERC20();
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
            modifyDelta(0),
            0.1 ether,
            LSSVMPair.PoolType.TRADE,
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
            modifyDelta(0),
            0.2 ether,
            LSSVMPair.PoolType.TRADE,
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
            modifyDelta(0),
            0.3 ether,
            LSSVMPair.PoolType.TRADE,
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
    function test_robustSwapTokenForAnyNFTs() public {
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
        // the first swapPair costs 0.22 tokens
        // the second swapPair costs 0.44 tokens
        // the third swapPair costs 0.66 tokens
        uint256 remainingValue = this.robustSwapTokenForAnyNFTs{
            value: modifyInputAmount(1.32 ether)
        }(
            router,
            swapList,
            maxCostPerNFTSwap,
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
    function test_robustSwapTokenForSpecificNFTs() public {
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
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair1,
            nftIds: nftIds1
        });
        swapList[1] = LSSVMRouter.PairSwapSpecific({
            pair: pair2,
            nftIds: nftIds2
        });
        swapList[2] = LSSVMRouter.PairSwapSpecific({
            pair: pair3,
            nftIds: nftIds3
        });

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
        uint256 remainingValue = this.robustSwapTokenForSpecificNFTs{
            value: modifyInputAmount(1.32 ether)
        }(
            router,
            swapList,
            maxCostPerNFTSwap,
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
    function test_robustSwapNFTsForToken() public {
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
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair1,
            nftIds: nftIds1
        });
        swapList[1] = LSSVMRouter.PairSwapSpecific({
            pair: pair2,
            nftIds: nftIds2
        });
        swapList[2] = LSSVMRouter.PairSwapSpecific({
            pair: pair3,
            nftIds: nftIds3
        });

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
        uint256 remainingValue = router.robustSwapNFTsForToken(
            swapList,
            minOutputPerSwapPair,
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
}
