// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {Test20} from "../../mocks/Test20.sol";
import {BeaconAmmV1PairFactory} from "../../BeaconAmmV1PairFactory.sol";
import {BeaconAmmV1RoyaltyManager} from "../../BeaconAmmV1RoyaltyManager.sol";
import {BeaconAmmV1Pair} from "../../BeaconAmmV1Pair.sol";
import {BeaconAmmV1PairETH} from "../../BeaconAmmV1PairETH.sol";
import {BeaconAmmV1PairERC20} from "../../BeaconAmmV1PairERC20.sol";
import {BeaconAmmV1PairEnumerableETH} from "../../BeaconAmmV1PairEnumerableETH.sol";
import {BeaconAmmV1PairMissingEnumerableETH} from "../../BeaconAmmV1PairMissingEnumerableETH.sol";
import {BeaconAmmV1PairEnumerableERC20} from "../../BeaconAmmV1PairEnumerableERC20.sol";
import {BeaconAmmV1PairMissingEnumerableERC20} from "../../BeaconAmmV1PairMissingEnumerableERC20.sol";
import {Configurable} from "../mixins/Configurable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Test721} from "../../mocks/Test721.sol";
import {TestPairManager} from "../../mocks/TestPairManager.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Test1155} from "../../mocks/Test1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

abstract contract PairAndFactory is DSTest, ERC721Holder, Configurable, ERC1155Holder {
    uint128 delta = 1.1 ether;
    uint128 spotPrice = 1 ether;
    uint256 tokenAmount = 10 ether;
    uint256 numItems = 2;
    uint256[] idList;
    IERC721 test721;
    Test1155 test1155;
    ERC20 testERC20;
    ICurve bondingCurve;
    BeaconAmmV1PairFactory factory;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    BeaconAmmV1Pair pair;
    TestPairManager pairManager;
    BeaconAmmV1RoyaltyManager royaltyManager;

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
        royaltyManager = new BeaconAmmV1RoyaltyManager(factory);
        factory.setRoyaltyManager(royaltyManager);
        factory.setBondingCurveAllowed(bondingCurve, true);
        test721.setApprovalForAll(address(factory), true);
        for (uint256 i = 1; i <= numItems; i++) {
            IERC721Mintable(address(test721)).mint(address(this), i);
            idList.push(i);
        }

        pair = this.setupPair{value: modifyInputAmount(tokenAmount)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            BeaconAmmV1Pair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            idList,
            tokenAmount,
            address(0)
        );
        test1155 = new Test1155();
        testERC20 = ERC20(address(new Test20()));
        IMintable(address(testERC20)).mint(address(pair), 1 ether);
        pairManager = new TestPairManager();
    }

    function testGas_basicDeploy() public {
        uint256[] memory empty;
        this.setupPair{value: modifyInputAmount(tokenAmount)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            BeaconAmmV1Pair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            empty,
            tokenAmount,
            address(0)
        );
    }

    /**
     * Test BeaconAmmV1Pair Owner functions
     */

    function test_transferOwnership() public {
        pair.transferOwnership(payable(address(2)));
        assertEq(pair.owner(), address(2));
    }

    function test_transferCallback() public {
        pair.transferOwnership(address(pairManager));
        assertEq(pairManager.prevOwner(), address(this));
    }

    function testGas_transferNoCallback() public {
        pair.transferOwnership(address(pair));
    }

    function testFail_transferOwnership() public {
        pair.transferOwnership(address(1000));
        pair.transferOwnership(payable(address(2)));
    }

    function test_rescueTokens() public {
        pair.withdrawERC721(test721, idList);
        pair.withdrawERC20(testERC20, 1 ether);
    }

    function testFail_tradePoolChangeAssetRecipient() public {
        pair.changeAssetRecipient(payable(address(1)));
    }

    function testFail_tradePoolChangeFeePastMax() public {
        pair.changeFee(100 ether);
    }

    function test_verifyPoolParams() public {
        // verify pair variables
        assertEq(address(pair.nft()), address(test721));
        assertEq(address(pair.bondingCurve()), address(bondingCurve));
        assertEq(uint256(pair.poolType()), uint256(BeaconAmmV1Pair.PoolType.TRADE));
        assertEq(pair.delta(), delta);
        assertEq(pair.spotPrice(), spotPrice);
        assertEq(pair.owner(), address(this));
        assertEq(pair.fee(), 0);
        assertEq(pair.assetRecipient(), address(0));
        assertEq(pair.getAssetRecipient(), address(pair));
        assertEq(getBalance(address(pair)), tokenAmount);

        // verify NFT ownership
        assertEq(test721.ownerOf(1), address(pair));
    }

    function test_modifyPairParams() public {
        // changing spot works as expected
        pair.changeSpotPrice(2 ether);
        assertEq(pair.spotPrice(), 2 ether);

        // changing delta works as expected
        pair.changeDelta(2.2 ether);
        assertEq(pair.delta(), 2.2 ether);

        // // changing fee works as expected
        pair.changeFee(0.2 ether);
        assertEq(pair.fee(), 0.2 ether);
    }

    function test_multicallModifyPairParams() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(pair.changeSpotPrice, (1 ether));
        calls[1] = abi.encodeCall(pair.changeDelta, (2 ether));
        calls[2] = abi.encodeCall(pair.changeFee, (0.3 ether));
        pair.multicall(calls, true);
        assertEq(pair.spotPrice(), 1 ether);
        assertEq(pair.delta(), 2 ether);
        assertEq(pair.fee(), 0.3 ether);
    }

    function testFail_multicallChangeOwnership() public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(pair.transferOwnership, (address(69)));
        calls[1] = abi.encodeCall(pair.changeDelta, (2 ether));
        pair.multicall(calls, true);
    }

    function test_getAllHeldNFTs() public {
        uint256[] memory allIds = pair.getAllHeldIds();
        for (uint256 i = 0; i < allIds.length; ++i) {
            assertEq(allIds[i], idList[i]);
        }
    }

    function test_withdraw() public {
        withdrawTokens(pair);
        assertEq(getBalance(address(pair)), 0);
    }

    function testFail_withdraw() public {
        pair.transferOwnership(address(1000));
        withdrawTokens(pair);
    }

    function test_withdraw1155() public {
        test1155.mint(address(pair), 1, 2);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        pair.withdrawERC1155(IERC1155(address(test1155)), ids, amounts);
        assertEq(IERC1155(address(test1155)).balanceOf(address(pair), 1), 0);
        assertEq(IERC1155(address(test1155)).balanceOf(address(this), 1), 2);
    }

    /**
        Test failure conditions
     */

    function testFail_rescueTokensNotOwner() public {
        pair.transferOwnership(address(1000));
        pair.withdrawERC721(test721, idList);
        pair.withdrawERC20(testERC20, 1 ether);
    }

    function testFail_changeAssetRecipientForTrade() public {
        pair.changeAssetRecipient(payable(address(1)));
    }

    function testFail_changeFeeAboveMax() public {
        pair.changeFee(100 ether);
    }

    function testFail_changeSpotNotOwner() public {
        pair.transferOwnership(address(1000));
        pair.changeSpotPrice(2 ether);
    }

    function testFail_changeDeltaNotOwner() public {
        pair.transferOwnership(address(1000));
        pair.changeDelta(2.2 ether);
    }

    function testFail_changeFeeNotOwner() public {
        pair.transferOwnership(address(1000));
        pair.changeFee(0.2 ether);
    }

    function testFail_reInitPool() public {
        pair.initialize(address(0), payable(address(0)), 0, 0, 0);
    }

    function testFail_swapForNFTNotInPool() public {
        (, uint128 newSpotPrice, , uint256 inputAmount, , , ) = bondingCurve
            .getBuyInfo(
                ICurve.PriceInfoParams({
                    spotPrice: spotPrice,
                    delta: delta,
                    numItems: numItems + 1,
                    feeMultiplier: 0,
                    protocolFeeMultiplier: protocolFeeMultiplier,
                    royaltyFeeMultiplier: 0
                })
            );

        // buy specific NFT not in pool
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 69;
        pair.swapTokenForSpecificNFTs{value: modifyInputAmount(inputAmount)}(
            nftIds,
            inputAmount,
            address(this),
            false,
            address(0)
        );
        spotPrice = uint56(newSpotPrice);
    }

    function testFail_swapForAnyNFTsPastBalance() public {
        (, uint128 newSpotPrice, , uint256 inputAmount, , , ) = bondingCurve
            .getBuyInfo(
                ICurve.PriceInfoParams({
                    spotPrice: spotPrice,
                    delta: delta,
                    numItems: numItems + 1,
                    feeMultiplier: 0,
                    protocolFeeMultiplier: protocolFeeMultiplier,
                    royaltyFeeMultiplier: 0
                })
            );

        // buy any NFTs past pool inventory
        pair.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
            numItems + 1,
            inputAmount,
            address(this),
            false,
            address(0)
        );
        spotPrice = uint56(newSpotPrice);
    }

    /**
     * Test Admin functions
     */

    function test_changeFeeRecipient() public {
        factory.changeProtocolFeeRecipient(payable(address(69)));
        assertEq(factory.protocolFeeRecipient(), address(69));
    }

    function test_withdrawFees() public {
        uint256 totalProtocolFee;
        uint256 factoryEndBalance;
        uint256 factoryStartBalance = getBalance(address(69));

        test721.setApprovalForAll(address(pair), true);

        // buy all NFTs
        {
            (
                ,
                uint128 newSpotPrice,
                ,
                uint256 inputAmount,
                uint256 protocolFee,
                ,
            ) = bondingCurve.getBuyInfo(
                    ICurve.PriceInfoParams({
                        spotPrice: spotPrice,
                        delta: delta,
                        numItems: numItems,
                        feeMultiplier: 0,
                        protocolFeeMultiplier: protocolFeeMultiplier,
                        royaltyFeeMultiplier: 0
                    })
                );
            totalProtocolFee += protocolFee;

            // buy NFTs
            pair.swapTokenForAnyNFTs{value: modifyInputAmount(inputAmount)}(
                numItems,
                inputAmount,
                address(this),
                false,
                address(0)
            );
            spotPrice = uint56(newSpotPrice);
        }

        this.withdrawProtocolFees(factory);

        factoryEndBalance = getBalance(address(69));
        assertEq(factoryEndBalance, factoryStartBalance + totalProtocolFee);
    }

    function test_changeFeeMultiplier() public {
        factory.changeProtocolFeeMultiplier(5e15);
        assertEq(factory.protocolFeeMultiplier(), 5e15);
    }

    function test_setRoyaltyManager() public {
        BeaconAmmV1RoyaltyManager newManager = new BeaconAmmV1RoyaltyManager(factory);
        factory.setRoyaltyManager(newManager);
        assertEq(address(factory.royaltyManager()), address(newManager));
    }
}
