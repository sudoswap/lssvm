// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

abstract contract PairAndFactory is DSTest, ERC721Holder, Configurable {
    uint256 delta = 1.1 ether;
    uint256 spotPrice = 1 ether;
    uint256 tokenAmount = 0.1 ether;
    uint256 numItems = 2;
    uint256[] idList;
    uint256[] idList2;
    IERC721 test721;
    IERC20 testERC20;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;
    LSSVMPair pair;

    function setUp() public {
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
            delta,
            spotPrice,
            LSSVMPair.PoolType.TRADE,
            idList,
            tokenAmount,
            address(0)
        );

        testERC20 = IERC20(address(new Test20()));
        IMintable(address(testERC20)).mint(address(pair), 1 ether);
    }

    function test_basicDeploy() public {
        uint256[] memory empty;
        this.setupPair{value: modifyInputAmount(tokenAmount)}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            delta,
            spotPrice,
            LSSVMPair.PoolType.TRADE,
            empty,
            tokenAmount,
            address(0)
        );
    }

    function test_transferOwnership() public {
        pair.transferOwnership(payable(address(2)));
    }

    function testFail_transferOwnership() public {
        pair.renounceOwnership();
        pair.transferOwnership(payable(address(2)));
    }

    function test_rescueTokens() public {
        pair.withdrawERC721(address(test721), idList);
        pair.withdrawERC20(address(testERC20), 1 ether);
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

    function test_withdraw() public {
        withdrawTokens(pair);
        assertEq(getBalance(address(pair)), 0);
    }

    function testFail_withdraw() public {
        pair.renounceOwnership();
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

    function testFail_rescueTokensNotOwner() public {
        pair.renounceOwnership();
        pair.withdrawERC721(address(test721), idList);
        pair.withdrawERC20(address(testERC20), 1 ether);
    }

    function testFail_changeAssetRecipientForTrade() public {
        pair.changeAssetRecipient(payable(address(1)));
    }

    function testFail_changeFeeAboveMax() public {
        pair.changeFee(100 ether);
    }

    function testFail_changeSpotNotOwner() public {
        pair.renounceOwnership();
        pair.changeSpotPrice(2 ether);
    }

    function testFail_changeDeltaNotOwner() public {
        pair.renounceOwnership();
        pair.changeDelta(2.2 ether);
    }

    function testFail_changeFeeNotOwner() public {
        pair.renounceOwnership();
        pair.changeFee(0.2 ether);
    }

    function testFail_reInitPool() public {
        pair.initialize(address(0), payable(address(0)), 0, 0, 0);
    }
}
