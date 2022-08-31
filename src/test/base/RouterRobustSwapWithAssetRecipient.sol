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

abstract contract RouterRobustSwapWithAssetRecipient is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;

    // 2 Sell Pairs
    LSSVMPair sellPair1;
    LSSVMPair sellPair2;

    // 2 Buy Pairs
    LSSVMPair buyPair1;
    LSSVMPair buyPair2;

    address payable constant feeRecipient = payable(address(69));
    address payable constant sellPairRecipient = payable(address(1));
    address payable constant buyPairRecipient = payable(address(2));
    uint256 constant protocolFeeMultiplier = 0;
    uint256 constant numInitialNFTs = 10;

    function setUp() public {
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

        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
        uint128 spotPrice = 1 ether;

        uint256[] memory sellIDList1 = new uint256[](1);
        sellIDList1[0] = 1;
        sellPair1 = this.setupPair{value: modifyInputAmount(1 ether)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            LSSVMPair.PoolType.NFT,
            modifyDelta(0),
            0,
            spotPrice,
            sellIDList1,
            1 ether,
            address(router)
        );

        uint256[] memory sellIDList2 = new uint256[](1);
        sellIDList2[0] = 2;
        sellPair2 = this.setupPair{value: modifyInputAmount(1 ether)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            LSSVMPair.PoolType.NFT,
            modifyDelta(0),
            0,
            spotPrice,
            sellIDList2,
            1 ether,
            address(router)
        );

        uint256[] memory buyIDList1 = new uint256[](1);
        buyIDList1[0] = 3;
        buyPair1 = this.setupPair{value: modifyInputAmount(1 ether)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            LSSVMPair.PoolType.TOKEN,
            modifyDelta(0),
            0,
            spotPrice,
            buyIDList1,
            1 ether,
            address(router)
        );

        uint256[] memory buyIDList2 = new uint256[](1);
        buyIDList2[0] = 4;
        buyPair2 = this.setupPair{value: modifyInputAmount(1 ether)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            LSSVMPair.PoolType.TOKEN,
            modifyDelta(0),
            0,
            spotPrice,
            buyIDList2,
            1 ether,
            address(router)
        );
    }

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
