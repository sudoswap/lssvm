// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
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
    BeaconAmmV1Factory factory;
    BeaconAmmV1Router router;

    // 2 Sell Pairs
    BeaconAmmV1 sellPair1;
    BeaconAmmV1 sellPair2;

    // 2 Buy Pairs
    BeaconAmmV1 buyPair1;
    BeaconAmmV1 buyPair2;

    address payable constant feeRecipient = payable(address(69));
    address payable constant sellPairRecipient = payable(address(1));
    address payable constant buyPairRecipient = payable(address(2));
    uint256 constant protocolFeeMultiplier = 0;
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
            BeaconAmmV1.PoolType.NFT,
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
            BeaconAmmV1.PoolType.NFT,
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
            BeaconAmmV1.PoolType.TOKEN,
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
            BeaconAmmV1.PoolType.TOKEN,
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
        BeaconAmmV1Router.RobustPairSwapAny[]
            memory swapList = new BeaconAmmV1Router.RobustPairSwapAny[](2);
        swapList[0] = BeaconAmmV1Router.RobustPairSwapAny({
            swapInfo: BeaconAmmV1Router.PairSwapAny({pair: sellPair1, numItems: 1}),
            maxCost: sellPair1Price
        });
        swapList[1] = BeaconAmmV1Router.RobustPairSwapAny({
            swapInfo: BeaconAmmV1Router.PairSwapAny({pair: sellPair2, numItems: 1}),
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
        BeaconAmmV1Router.RobustPairSwapSpecific[]
            memory swapList = new BeaconAmmV1Router.RobustPairSwapSpecific[](2);
        uint256[] memory nftIds1 = new uint256[](1);
        nftIds1[0] = 1;
        uint256[] memory nftIds2 = new uint256[](1);
        nftIds2[0] = 2;
        swapList[0] = BeaconAmmV1Router.RobustPairSwapSpecific({
            swapInfo: BeaconAmmV1Router.PairSwapSpecific({
                pair: sellPair1,
                nftIds: nftIds1
            }),
            maxCost: 0 ether
        });
        swapList[1] = BeaconAmmV1Router.RobustPairSwapSpecific({
            swapInfo: BeaconAmmV1Router.PairSwapSpecific({
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
        BeaconAmmV1Router.RobustPairSwapSpecificForToken[]
            memory swapList = new BeaconAmmV1Router.RobustPairSwapSpecificForToken[](
                2
            );
        swapList[0] = BeaconAmmV1Router.RobustPairSwapSpecificForToken({
            swapInfo: BeaconAmmV1Router.PairSwapSpecific({
                pair: buyPair1,
                nftIds: nftIds1
            }),
            minOutput: buyPair1Price
        });
        swapList[1] = BeaconAmmV1Router.RobustPairSwapSpecificForToken({
            swapInfo: BeaconAmmV1Router.PairSwapSpecific({
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
