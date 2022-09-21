// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Configurable} from "../mixins/Configurable.sol";

import {BeaconAmmV1Pair} from "../../BeaconAmmV1Pair.sol";
import {BeaconAmmV1PairETH} from "../../BeaconAmmV1PairETH.sol";
import {BeaconAmmV1PairERC20} from "../../BeaconAmmV1PairERC20.sol";
import {BeaconAmmV1PairEnumerableETH} from "../../BeaconAmmV1PairEnumerableETH.sol";
import {BeaconAmmV1PairMissingEnumerableETH} from "../../BeaconAmmV1PairMissingEnumerableETH.sol";
import {BeaconAmmV1PairEnumerableERC20} from "../../BeaconAmmV1PairEnumerableERC20.sol";
import {BeaconAmmV1PairMissingEnumerableERC20} from "../../BeaconAmmV1PairMissingEnumerableERC20.sol";
import {BeaconAmmV1PairFactory} from "../../BeaconAmmV1PairFactory.sol";
import {BeaconAmmV1RoyaltyManager} from "../../BeaconAmmV1RoyaltyManager.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {CurveErrorCodes} from "../../bonding-curves/CurveErrorCodes.sol";
import {Test721} from "../../mocks/Test721.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract NoArbBondingCurve is DSTest, ERC721Holder, Configurable {
    using FixedPointMathLib for uint256;

    uint256[] idList;
    uint256 startingId;
    IERC721Mintable test721;
    ICurve bondingCurve;
    BeaconAmmV1PairFactory factory;
    BeaconAmmV1RoyaltyManager royaltyManager;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    uint96 constant pairFee = 10e16;
    uint256 constant royaltyFeeMultiplier = 1e17; // 10%
    address payable constant royaltyFeeRecipient = payable(address(6));

    function setUp() public {
        bondingCurve = setupCurve();
        test721 = setup721();
        BeaconAmmV1PairEnumerableETH enumerableETHTemplate = new BeaconAmmV1PairEnumerableETH();
        BeaconAmmV1PairMissingEnumerableETH missingEnumerableETHTemplate = new BeaconAmmV1PairMissingEnumerableETH();
        BeaconAmmV1PairEnumerableERC20 enumerableERC20Template = new BeaconAmmV1PairEnumerableERC20();
        BeaconAmmV1PairMissingEnumerableERC20 missingEnumerableERC20Template = new BeaconAmmV1PairMissingEnumerableERC20();
        factory = new BeaconAmmV1PairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            feeRecipient,
            protocolFeeMultiplier
        );
        test721.setApprovalForAll(address(factory), true);
        factory.setBondingCurveAllowed(bondingCurve, true);
    }

    /**
    @dev Ensures selling NFTs & buying them back results in no profit.
     */
    function test_bondingCurveSellBuyNoProfit(
        uint56 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public payable {
        // modify spotPrice to be appropriate for the bonding curve
        spotPrice = modifySpotPrice(spotPrice);

        // modify delta to be appropriate for the bonding curve
        delta = modifyDelta(delta);

        // decrease the range of numItems to speed up testing
        numItems = numItems % 3;

        if (numItems == 0) {
            return;
        }

        delete idList;

        // initialize the pair
        uint256[] memory empty;
        BeaconAmmV1Pair pair = setupPair(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            BeaconAmmV1Pair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            empty,
            0,
            address(0)
        );

        // mint NFTs to sell to the pair
        for (uint256 i = 0; i < numItems; i++) {
            test721.mint(address(this), startingId);
            idList.push(startingId);
            startingId += 1;
        }

        uint256 startBalance;
        uint256 endBalance;

        // sell all NFTs minted to the pair
        {
            (
                ,
                uint256 newSpotPrice,
                ,
                uint256 outputAmount,
                uint256 protocolFee,
                ,
            ) = bondingCurve.getSellInfo(
                    ICurve.PriceInfoParams({
                        spotPrice: spotPrice,
                        delta: delta,
                        numItems: numItems,
                        feeMultiplier: 0,
                        protocolFeeMultiplier: protocolFeeMultiplier,
                        royaltyFeeMultiplier: 0
                    })
                );

            // give the pair contract enough tokens to pay for the NFTs
            sendTokens(pair, outputAmount + protocolFee);

            // sell NFTs
            test721.setApprovalForAll(address(pair), true);
            startBalance = getBalance(address(this));
            pair.swapNFTsForToken(
                idList,
                0,
                payable(address(this)),
                false,
                address(0)
            );
            spotPrice = uint56(newSpotPrice);
        }

        // buy back the NFTs just sold to the pair
        {
            (, , , uint256 inputAmount, , , ) = bondingCurve.getBuyInfo(
                ICurve.PriceInfoParams({
                    spotPrice: spotPrice,
                    delta: delta,
                    numItems: numItems,
                    feeMultiplier: 0,
                    protocolFeeMultiplier: protocolFeeMultiplier,
                    royaltyFeeMultiplier: 0
                })
            );
            pair.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
                idList.length,
                inputAmount,
                address(this),
                false,
                address(0)
            );
            endBalance = getBalance(address(this));
        }

        // ensure the caller didn't profit from the aggregate trade
        assertGeDecimal(startBalance, endBalance, 18);

        // withdraw the tokens in the pair back
        withdrawTokens(pair);
    }

    /**
    @dev Ensures buying NFTs & selling them back results in no profit.
     */
    function test_bondingCurveBuySellNoProfit(
        uint56 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public payable {
        // modify spotPrice to be appropriate for the bonding curve
        spotPrice = modifySpotPrice(spotPrice);

        // modify delta to be appropriate for the bonding curve
        delta = modifyDelta(delta);

        // decrease the range of numItems to speed up testing
        numItems = numItems % 3;

        if (numItems == 0) {
            return;
        }

        delete idList;

        // initialize the pair
        for (uint256 i = 0; i < numItems; i++) {
            test721.mint(address(this), startingId);
            idList.push(startingId);
            startingId += 1;
        }
        BeaconAmmV1Pair pair = setupPair(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            BeaconAmmV1Pair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            idList,
            0,
            address(0)
        );
        test721.setApprovalForAll(address(pair), true);

        uint256 startBalance;
        uint256 endBalance;

        // buy all NFTs
        {
            (, uint256 newSpotPrice, , uint256 inputAmount, , , ) = bondingCurve
                .getBuyInfo(
                    ICurve.PriceInfoParams({
                        spotPrice: spotPrice,
                        delta: delta,
                        numItems: numItems,
                        feeMultiplier: 0,
                        protocolFeeMultiplier: protocolFeeMultiplier,
                        royaltyFeeMultiplier: 0
                    })
                );

            // buy NFTs
            startBalance = getBalance(address(this));
            pair.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
                numItems,
                inputAmount,
                address(this),
                false,
                address(0)
            );
            spotPrice = uint56(newSpotPrice);
        }

        // sell back the NFTs
        {
            pair.swapNFTsForToken(
                idList,
                0,
                payable(address(this)),
                false,
                address(0)
            );
            endBalance = getBalance(address(this));
        }

        // ensure the caller didn't profit from the aggregate trade
        assertGeDecimal(startBalance, endBalance, 18);

        // withdraw the tokens in the pair back
        withdrawTokens(pair);
    }

    /**
     * Test Royalty fee and protocol fee on buy and sell
     */
    function test_bondingCurveSellRoyaltyAndProtocolFee(
       uint56 spotPrice,
       uint64 delta,
       uint8 numItems
    ) public payable {
       // modify spotPrice to be appropriate for the bonding curve
       spotPrice = modifySpotPrice(spotPrice);

       // modify delta to be appropriate for the bonding curve
       delta = modifyDelta(delta);

       // decrease the range of numItems to speed up testing
       numItems = numItems % 3;

       if (numItems == 0) {
           return;
       }

       delete idList;

       // initialize the pair
       uint256[] memory empty;
       BeaconAmmV1Pair pair = setupPair(
           factory,
           test721,
           bondingCurve,
           payable(address(0)),
           BeaconAmmV1Pair.PoolType.TRADE,
           delta,
           pairFee,
           spotPrice,
           empty,
           0,
           address(0)
       );

       // Setup royalty
       royaltyManager = setupRoyaltyManager(factory, address(pair.nft()), royaltyFeeMultiplier, royaltyFeeRecipient);
       factory.setRoyaltyManager(royaltyManager);

       // mint NFTs to sell to the pair
       for (uint256 i = 0; i < numItems; i++) {
           test721.mint(address(this), startingId);
           idList.push(startingId);
           startingId += 1;
       }

       // sell all NFTs minted to the pair
       (
           ,
           uint256 newSpotPrice,
           ,
           uint256 outputAmount,
           uint256 protocolFee,
           uint256 tradeFee,
           uint256 royaltyFee
       ) = bondingCurve.getSellInfo(
               ICurve.PriceInfoParams({
                   spotPrice: spotPrice,
                   delta: delta,
                   numItems: numItems,
                   feeMultiplier: pairFee,
                   protocolFeeMultiplier: protocolFeeMultiplier,
                   royaltyFeeMultiplier: royaltyFeeMultiplier
               })
           );

       // give the pair contract enough tokens to pay for the NFTs
       sendTokens(pair, outputAmount + protocolFee + tradeFee + royaltyFee);

       // sell NFTs
       test721.setApprovalForAll(address(pair), true);
       pair.swapNFTsForToken(
           idList,
           0,
           payable(address(this)),
           false,
           address(0)
       );

       // factory should have protocol fee amount
       assertEq(getBalance(address(factory)), protocolFee);
       // royalty recipient should have royalty amount
       address royaltyRecipient = royaltyManager.getFeeRecipient(address(pair.nft()));
       assertEq(getBalance(address(royaltyRecipient)), royaltyFee);
       // pair should have trade fee amount
       assertEq(getBalance(address(pair)), tradeFee);
    }

    function test_bondingCurveBuyRoyaltyAndProtocolFee(
        uint56 spotPrice,
        uint64 delta,
        uint8 numItems
    ) public payable {
        // modify spotPrice to be appropriate for the bonding curve
        spotPrice = modifySpotPrice(spotPrice);

        // modify delta to be appropriate for the bonding curve
        delta = modifyDelta(delta);

        // decrease the range of numItems to speed up testing
        numItems = numItems % 3;

        if (numItems == 0) {
            return;
        }

        delete idList;

        // initialize the pair
        for (uint256 i = 0; i < numItems; i++) {
            test721.mint(address(this), startingId);
            idList.push(startingId);
            startingId += 1;
        }
        BeaconAmmV1Pair pair = setupPair(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            BeaconAmmV1Pair.PoolType.TRADE,
            delta,
            pairFee,
            spotPrice,
            idList,
            0,
            address(0)
        );
        test721.setApprovalForAll(address(pair), true);

        // Setup royalty
        royaltyManager = setupRoyaltyManager(factory, address(pair.nft()), royaltyFeeMultiplier, royaltyFeeRecipient);
        factory.setRoyaltyManager(royaltyManager);

        // buy all NFTs
        (, uint256 newSpotPrice, , uint256 inputAmount, uint256 protocolFee, uint256 tradeFee, uint256 royaltyFee) = bondingCurve
            .getBuyInfo(
                ICurve.PriceInfoParams({
                    spotPrice: spotPrice,
                    delta: delta,
                    numItems: numItems,
                    feeMultiplier: pairFee,
                    protocolFeeMultiplier: protocolFeeMultiplier,
                    royaltyFeeMultiplier: royaltyFeeMultiplier
                })
            );

        // buy NFTs
        pair.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            numItems,
            inputAmount,
            address(this),
            false,
            address(0)
        );
        spotPrice = uint56(newSpotPrice);

        // factory should have protocol fee amount
        assertEq(getBalance(address(factory)), protocolFee);
        // royalty recipient should have royalty amount
        address royaltyRecipient = royaltyManager.getFeeRecipient(address(pair.nft()));
        assertEq(getBalance(address(royaltyRecipient)), royaltyFee);
        // pair should have inputAmount - royaltyFee - protocolFee
        assertEq(getBalance(address(pair)), inputAmount - royaltyFee - protocolFee);
    }
}
