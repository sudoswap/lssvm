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
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Test721} from "../../mocks/Test721.sol";

import {Hevm} from "../utils/Hevm.sol";

contract XykCurveTest is DSTest, ERC721Holder {
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

    receive() external payable {}

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
            uint128(numNfts),
            0,
            uint128(value),
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

    function test_getSellInfoCannotHave0NumItems() public {
        // arrange
        uint256 numItems = 0;

        // act
        (CurveErrorCodes.Error error, , , , ) = curve.getSellInfo(
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

    function test_getBuyInfoReturnsNewReserves() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 1 ether;
        setUpEthPair(numNfts, value);
        uint256 numItemsToBuy = 2;

        // act
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 newDelta,
            uint256 inputValue,

        ) = ethPair.getBuyNFTQuote(numItemsToBuy);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            newDelta,
            numNfts - numItemsToBuy,
            "Should have updated virtual nft reserve"
        );
        assertEq(
            newSpotPrice,
            inputValue + value,
            "Should have updated virtual eth reserve"
        );
    }

    function test_getSellInfoReturnsNewReserves() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 1 ether;
        setUpEthPair(numNfts, value);
        uint256 numItemsToSell = 2;

        // act
        (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 newDelta,
            uint256 inputValue,

        ) = ethPair.getSellNFTQuote(numItemsToSell);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            newDelta,
            numNfts + numItemsToSell,
            "Should have updated virtual nft reserve"
        );
        assertEq(
            newSpotPrice,
            value - inputValue,
            "Should have updated virtual eth reserve"
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

    function test_getSellInfoReturnsOutputValue() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 0.8 ether;
        setUpEthPair(numNfts, value);
        uint256 numItemsToSell = 3;
        uint256 expectedOutputValue = (numItemsToSell * value) /
            (numNfts + numItemsToSell);

        // act
        (CurveErrorCodes.Error error, , , uint256 outputValue, ) = ethPair
            .getSellNFTQuote(numItemsToSell);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            outputValue,
            expectedOutputValue,
            "Should have calculated output value"
        );
    }

    function test_getBuyInfoCalculatesProtocolFee() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 0.8 ether;
        setUpEthPair(numNfts, value);
        factory.changeProtocolFeeMultiplier((2 * 1e18) / 100); // 2%
        uint256 numItemsToBuy = 3;
        uint256 expectedProtocolFee = (2 *
            ((numItemsToBuy * value) / (numNfts - numItemsToBuy))) / 100;

        // act
        (CurveErrorCodes.Error error, , , , uint256 protocolFee) = ethPair
            .getBuyNFTQuote(numItemsToBuy);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            protocolFee,
            expectedProtocolFee,
            "Should have calculated protocol fee"
        );
    }

    function test_getSellInfoCalculatesProtocolFee() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 0.8 ether;
        setUpEthPair(numNfts, value);
        factory.changeProtocolFeeMultiplier((2 * 1e18) / 100); // 2%
        uint256 numItemsToSell = 3;
        uint256 expectedProtocolFee = (2 *
            ((numItemsToSell * value) / (numNfts + numItemsToSell))) / 100;

        // act
        (CurveErrorCodes.Error error, , , , uint256 protocolFee) = ethPair
            .getSellNFTQuote(numItemsToSell);

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            protocolFee,
            expectedProtocolFee,
            "Should have calculated protocol fee"
        );
    }

    function test_swapTokenForAnyNFTs() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 0.8 ether;
        setUpEthPair(numNfts, value);
        uint256 numItemsToBuy = 2;
        uint256 ethBalanceBefore = address(this).balance;
        uint256 nftBalanceBefore = nft.balanceOf(address(this));

        factory.changeProtocolFeeMultiplier((2 * 1e18) / 100); // 2%
        ethPair.changeFee((1 * 1e18) / 100); // 1%

        (CurveErrorCodes.Error error, , , uint256 inputValue, ) = ethPair
            .getBuyNFTQuote(numItemsToBuy);

        // act
        uint256 inputAmount = ethPair.swapTokenForAnyNFTs{value: inputValue}(
            numItemsToBuy,
            inputValue,
            address(this),
            false,
            address(0)
        );

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            ethBalanceBefore - address(this).balance,
            inputValue,
            "Should have transferred ETH"
        );
        assertEq(
            nft.balanceOf(address(this)) - nftBalanceBefore,
            numItemsToBuy,
            "Should have received NFTs"
        );

        uint256 withoutFeeInputAmount = (inputAmount * 1e18) / 103e16;
        assertEq(
            ethPair.spotPrice(),
            uint128(address(ethPair).balance) -
                (withoutFeeInputAmount * 1e16) /
                1e18,
            "Spot price should match eth balance - fee after swap"
        );
        assertEq(
            ethPair.delta(),
            nft.balanceOf(address(ethPair)),
            "Delta should match nft balance after swap"
        );
    }

    function test_swapNFTsForToken() public {
        // arrange
        uint256 numNfts = 5;
        uint256 value = 0.8 ether;
        setUpEthPair(numNfts, value);

        factory.changeProtocolFeeMultiplier((2 * 1e18) / 100); // 2%
        ethPair.changeFee((1 * 1e18) / 100); // 1%

        uint256 numItemsToSell = 2;
        (CurveErrorCodes.Error error, , , uint256 outputValue, ) = ethPair
            .getSellNFTQuote(numItemsToSell);

        uint256[] memory idList = new uint256[](numItemsToSell);
        for (uint256 i = 1; i <= numItemsToSell; i++) {
            nft.mint(address(this), numNfts + i);
            idList[i - 1] = numNfts + i;
        }

        uint256 ethBalanceBefore = address(this).balance;
        uint256 nftBalanceBefore = nft.balanceOf(address(this));
        nft.setApprovalForAll(address(ethPair), true);

        // act
        uint256 outputAmount = ethPair.swapNFTsForToken(
            idList,
            outputValue,
            payable(address(this)),
            false,
            address(0)
        );

        // assert
        assertEq(
            uint256(error),
            uint256(CurveErrorCodes.Error.OK),
            "Should not have errored"
        );
        assertEq(
            address(this).balance - ethBalanceBefore,
            outputValue,
            "Should have received ETH"
        );
        assertEq(
            nftBalanceBefore - nft.balanceOf(address(this)),
            numItemsToSell,
            "Should have sent NFTs"
        );

        uint256 withoutFeeOutputAmount = (outputAmount * 1e18) / 0.97e18;
        assertEq(
            ethPair.spotPrice(),
            uint128(address(ethPair).balance) -
                ((withoutFeeOutputAmount * 1e16) / 1e18),
            "Spot price + fee should match eth balance after swap"
        );
        assertEq(
            ethPair.delta(),
            nft.balanceOf(address(ethPair)),
            "Delta should match nft balance after swap"
        );
    }
}
