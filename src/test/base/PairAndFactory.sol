// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {Test20} from "../../mocks/Test20.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairETH} from "../../LSSVMPairETH.sol";
import {LSSVMPairERC20} from "../../LSSVMPairERC20.sol";
import {LSSVMPairEnumerableETH} from "../../LSSVMPairEnumerableETH.sol";
import {LSSVMPairMissingEnumerableETH} from "../../LSSVMPairMissingEnumerableETH.sol";
import {LSSVMPairEnumerableERC20} from "../../LSSVMPairEnumerableERC20.sol";
import {LSSVMPairMissingEnumerableERC20} from "../../LSSVMPairMissingEnumerableERC20.sol";
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
    LSSVMPairFactory factory;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    LSSVMPair pair;
    TestPairManager pairManager;

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
            LSSVMPair.PoolType.TRADE,
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
            LSSVMPair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            empty,
            tokenAmount,
            address(0)
        );
    }

    /**
     * Test LSSVMPair Owner functions
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
        assertEq(uint256(pair.poolType()), uint256(LSSVMPair.PoolType.TRADE));
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

    function testFail_callMint721() public {
        bytes memory data = abi.encodeWithSelector(
            Test721.mint.selector,
            address(this),
            1000
        );
        pair.call(payable(address(test721)), data);
    }

    function test_callMint721() public {
        // arbitrary call (just call mint on Test721) works as expected

        // add to whitelist
        factory.setCallAllowed(payable(address(test721)), true);

        bytes memory data = abi.encodeWithSelector(
            Test721.mint.selector,
            address(this),
            1000
        );
        pair.call(payable(address(test721)), data);

        // verify NFT ownership
        assertEq(test721.ownerOf(1000), address(this));
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
        (, uint128 newSpotPrice, , uint256 inputAmount, ) = bondingCurve
            .getBuyInfo(
                spotPrice,
                delta,
                numItems + 1,
                0,
                protocolFeeMultiplier
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
        (, uint128 newSpotPrice, , uint256 inputAmount, ) = bondingCurve
            .getBuyInfo(
                spotPrice,
                delta,
                numItems + 1,
                0,
                protocolFeeMultiplier
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
                uint256 protocolFee
            ) = bondingCurve.getBuyInfo(
                    spotPrice,
                    delta,
                    numItems,
                    0,
                    protocolFeeMultiplier
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
}
