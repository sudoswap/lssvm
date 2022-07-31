// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {XykCurve} from "../../bonding-curves/XykCurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {LSSVMPairEnumerableETH} from "../../LSSVMPairEnumerableETH.sol";
import {LSSVMPairMissingEnumerableETH} from "../../LSSVMPairMissingEnumerableETH.sol";
import {LSSVMPairEnumerableERC20} from "../../LSSVMPairEnumerableERC20.sol";
import {LSSVMPairMissingEnumerableERC20} from "../../LSSVMPairMissingEnumerableERC20.sol";
import {LSSVMPairCloner} from "../../lib/LSSVMPairCloner.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Test721} from "../../mocks/Test721.sol";

import {Hevm} from "../utils/Hevm.sol";

contract XykCurveTest is DSTest {
    using FixedPointMathLib for uint256;

    uint256 constant MIN_PRICE = 1 gwei;

    XykCurve curve;
    LSSVMPairFactory factory;
    LSSVMPairEnumerableETH enumerableETHTemplate;
    LSSVMPairMissingEnumerableETH missingEnumerableETHTemplate;
    LSSVMPairEnumerableERC20 enumerableERC20Template;
    LSSVMPairMissingEnumerableERC20 missingEnumerableERC20Template;
    LSSVMPair ethPair;
    Test721 nft;

    function setUp() public {
        enumerableETHTemplate = new LSSVMPairEnumerableETH();
        missingEnumerableETHTemplate = new LSSVMPairMissingEnumerableETH();
        enumerableERC20Template = new LSSVMPairEnumerableERC20();
        missingEnumerableERC20Template = new LSSVMPairMissingEnumerableERC20();

        factory = new LSSVMPairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            payable(0),
            0
        );

        curve = new XykCurve();
        factory.setBondingCurveAllowed(curve, true);
    }

    function setUpEthPair(uint256 numNfts, uint256 value) public {
        nft = new Test721();
        nft.setApprovalForAll(address(factory), true);
        uint256[] memory idList = new uint256[](numNfts);
        for (uint256 i = 1; i <= numNfts; i++) {
            nft.mint(address(this), i);
            idList[i - 1] = i;
        }

        ethPair = factory.createPairETH{value: value}(
            nft,
            curve,
            payable(0),
            LSSVMPair.PoolType.TRADE,
            0,
            0,
            0,
            idList
        );
    }

    function test_getBuyInfoCannotHave0NumItems() public {
        // arrange
        uint256 numItems = 0;

        // act
        (CurveErrorCodes.Error error, , , , ) = curve.getBuyInfo(
            0,
            0,
            numItems,
            0,
            0
        );

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.INVALID_NUMITEMS),
            "Should have returned invalid num items error"
        );
    }

    function test_getBuyInfoReturnsSpotPrice() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 1 ether;
        setUpEthPair(numNfts, value);
        uint256 numItemsToBuy = 2;
        uint256 expectedNewSpotPrice = (value +
            (numItemsToBuy * value) /
            (numNfts - numItemsToBuy)) / (numNfts - numItemsToBuy);

        // act
        (CurveErrorCodes.Error error, uint256 newSpotPrice, , , ) = ethPair
            .getBuyNFTQuote(numItemsToBuy);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            newSpotPrice,
            expectedNewSpotPrice,
            "Should have calculated spot price"
        );
    }

    function test_getBuyInfoReturnsInputValue() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 0.8 ether;
        setUpEthPair(numNfts, value);
        uint256 numItemsToBuy = 3;
        uint256 expectedInputValue = (numItemsToBuy * value) /
            (numNfts - numItemsToBuy);

        // act
        (CurveErrorCodes.Error error, , , uint256 inputValue, ) = ethPair
            .getBuyNFTQuote(numItemsToBuy);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            inputValue,
            expectedInputValue,
            "Should have calculated input value"
        );
    }

    function test_sellReturnsSpotPrice() public {}

    function test_buyCalculatesFee() public {}

    function test_buyCalculatesProtocolFee() public {}

    function test_isETHPair() public {
        // arrange
        address enumerableETHPair = LSSVMPairCloner.cloneETHPair(
            address(enumerableETHTemplate),
            factory,
            curve,
            IERC721(address(0)),
            uint8(2)
        );
        address missingEnumerableETHPair = LSSVMPairCloner.cloneETHPair(
            address(missingEnumerableETHTemplate),
            factory,
            curve,
            IERC721(address(0)),
            uint8(2)
        );
        address enumerableERC20Pair = LSSVMPairCloner.cloneERC20Pair(
            address(enumerableERC20Template),
            factory,
            curve,
            IERC721(address(0)),
            uint8(2),
            ERC20(address(0))
        );
        address missingEnumerableERC20Pair = LSSVMPairCloner.cloneERC20Pair(
            address(missingEnumerableERC20Template),
            factory,
            curve,
            IERC721(address(0)),
            uint8(2),
            ERC20(address(0))
        );

        // act
        bool isEnumerableETHPairETHPair = curve.isETHPair(
            LSSVMPair(enumerableETHPair)
        );
        bool isMissingEnumerableETHPairETHPair = curve.isETHPair(
            LSSVMPair(missingEnumerableETHPair)
        );
        bool isEnumerableERC20PairETHPair = curve.isETHPair(
            LSSVMPair(enumerableERC20Pair)
        );
        bool isMissingEnumerableERC20PairETHPair = curve.isETHPair(
            LSSVMPair(missingEnumerableERC20Pair)
        );

        // assert
        assertTrue(
            isEnumerableETHPairETHPair,
            "Enumerable ETH pair should be detected as an ETH pair"
        );
        assertTrue(
            isMissingEnumerableETHPairETHPair,
            "Missing enumerable ETH pair should be detected as an ETH pair"
        );
        assertTrue(
            !isEnumerableERC20PairETHPair,
            "Enumerable ERC20 pair should not be detected as an ETH pair"
        );
        assertTrue(
            !isMissingEnumerableERC20PairETHPair,
            "Missing enumerable ERC20 pair should not be detected as an ETH pair"
        );
    }

    // function test_getBuyInfoExample() public {
    //     uint128 spotPrice = 3 ether;
    //     uint128 delta = 2 ether; // 2
    //     uint256 numItems = 5;
    //     uint256 feeMultiplier = (FixedPointMathLib.WAD * 5) / 1000; // 0.5%
    //     uint256 protocolFeeMultiplier = (FixedPointMathLib.WAD * 3) / 1000; // 0.3%
    //     (
    //         CurveErrorCodes.Error error,
    //         uint256 newSpotPrice,
    //         uint256 newDelta,
    //         uint256 inputValue,
    //         uint256 protocolFee
    //     ) = curve.getBuyInfo(
    //             spotPrice,
    //             delta,
    //             numItems,
    //             feeMultiplier,
    //             protocolFeeMultiplier
    //         );
    //     assertEq(
    //         uint256(error),
    //         uint256(CurveErrorCodes.Error.OK),
    //         "Error code not OK"
    //     );
    //     assertEq(newSpotPrice, 96 ether, "Spot price incorrect");
    //     assertEq(newDelta, 2 ether, "Delta incorrect");
    //     assertEq(inputValue, 187.488 ether, "Input value incorrect");
    //     assertEq(protocolFee, 0.558 ether, "Protocol fee incorrect");
    // }

    // function test_getBuyInfoWithoutFee(
    //     uint128 spotPrice,
    //     uint64 delta,
    //     uint8 numItems
    // ) public {
    //     if (
    //         delta < FixedPointMathLib.WAD ||
    //         numItems > 10 ||
    //         spotPrice < MIN_PRICE ||
    //         numItems == 0
    //     ) {
    //         return;
    //     }

    //     (
    //         CurveErrorCodes.Error error,
    //         uint256 newSpotPrice,
    //         uint256 newDelta,
    //         uint256 inputValue,

    //     ) = curve.getBuyInfo(spotPrice, delta, numItems, 0, 0);
    //     uint256 deltaPowN = uint256(delta).fpow(
    //         numItems,
    //         FixedPointMathLib.WAD
    //     );
    //     uint256 fullWidthNewSpotPrice = uint256(spotPrice).fmul(
    //         deltaPowN,
    //         FixedPointMathLib.WAD
    //     );
    //     if (fullWidthNewSpotPrice > type(uint128).max) {
    //         assertEq(
    //             uint256(error),
    //             uint256(CurveErrorCodes.Error.SPOT_PRICE_OVERFLOW),
    //             "Error code not SPOT_PRICE_OVERFLOW"
    //         );
    //     } else {
    //         assertEq(
    //             uint256(error),
    //             uint256(CurveErrorCodes.Error.OK),
    //             "Error code not OK"
    //         );

    //         if (spotPrice > 0 && numItems > 0) {
    //             assertTrue(
    //                 (newSpotPrice > spotPrice &&
    //                     delta > FixedPointMathLib.WAD) ||
    //                     (newSpotPrice == spotPrice &&
    //                         delta == FixedPointMathLib.WAD),
    //                 "Price update incorrect"
    //             );
    //         }

    //         assertGe(
    //             inputValue,
    //             numItems * uint256(spotPrice),
    //             "Input value incorrect"
    //         );
    //     }
    // }

    // function test_getSellInfoExample() public {
    //     uint128 spotPrice = 3 ether;
    //     uint128 delta = 2 ether; // 2
    //     uint256 numItems = 5;
    //     uint256 feeMultiplier = (FixedPointMathLib.WAD * 5) / 1000; // 0.5%
    //     uint256 protocolFeeMultiplier = (FixedPointMathLib.WAD * 3) / 1000; // 0.3%
    //     (
    //         CurveErrorCodes.Error error,
    //         uint256 newSpotPrice,
    //         uint256 newDelta,
    //         uint256 outputValue,
    //         uint256 protocolFee
    //     ) = curve.getSellInfo(
    //             spotPrice,
    //             delta,
    //             numItems,
    //             feeMultiplier,
    //             protocolFeeMultiplier
    //         );
    //     assertEq(
    //         uint256(error),
    //         uint256(CurveErrorCodes.Error.OK),
    //         "Error code not OK"
    //     );
    //     assertEq(newSpotPrice, 0.09375 ether, "Spot price incorrect");
    //     assertEq(newDelta, 2 ether, "Delta incorrect");
    //     assertEq(outputValue, 5.766 ether, "Output value incorrect");
    //     assertEq(protocolFee, 0.0174375 ether, "Protocol fee incorrect");
    // }

    // function test_getSellInfoWithoutFee(
    //     uint128 spotPrice,
    //     uint128 delta,
    //     uint8 numItems
    // ) public {
    //     if (
    //         delta < FixedPointMathLib.WAD ||
    //         spotPrice < MIN_PRICE ||
    //         numItems == 0
    //     ) {
    //         return;
    //     }

    //     (
    //         CurveErrorCodes.Error error,
    //         uint256 newSpotPrice,
    //         ,
    //         uint256 outputValue,

    //     ) = curve.getSellInfo(spotPrice, delta, numItems, 0, 0);
    //     assertEq(
    //         uint256(error),
    //         uint256(CurveErrorCodes.Error.OK),
    //         "Error code not OK"
    //     );

    //     if (spotPrice > MIN_PRICE && numItems > 0) {
    //         assertTrue(
    //             (newSpotPrice < spotPrice && delta > 0) ||
    //                 (newSpotPrice == spotPrice && delta == 0),
    //             "Price update incorrect"
    //         );
    //     }

    //     assertLe(
    //         outputValue,
    //         numItems * uint256(spotPrice),
    //         "Output value incorrect"
    //     );
    // }
}
