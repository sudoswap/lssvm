// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Test1155} from "../../mocks/Test1155.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {IERC1155Mintable} from "../interfaces/IERC1155Mintable.sol";
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

abstract contract PairFactoryBase is
    DSTest,
    ERC721Holder,
    ERC1155Holder,
    Configurable
{
    uint256 delta = 1.1 ether;
    uint256 spotPrice = 1 ether;
    uint256 tokenAmount = 0.1 ether;
    uint256 numItems = 2;
    uint256[] idList;
    IERC721 test721;
    IERC1155 test1155;
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
            delta,
            spotPrice,
            idList,
            tokenAmount,
            address(0)
        );
    }

    function test_createPair_owner_rescueERC721ERC20ERC1155() public {
        pair.withdrawERC721(address(test721), idList);
    }

    function testFail_createPair_tradePool_owner_changeAssetRecipient() public {
        pair.changeAssetRecipient(payable(address(1)));
    }

    function testFail_createPair_tradePool_owner_revertChangeFee() public {
        pair.changeFee(100 ether);
    }

    function test_createPair_tradePool_owner_changeSpotDeltaFee() public {
        // verify pair variables
        assertEq(address(pair.nft()), address(test721));
        assertEq(address(pair.bondingCurve()), address(bondingCurve));
        assertEq(uint256(pair.poolType()), uint256(LSSVMPair.PoolType.TRADE));
        assertEq(pair.delta(), delta);
        assertEq(pair.spotPrice(), spotPrice);
        assertEq(pair.owner(), address(this));
        assertEq(pair.fee(), 0);
        assertEq(pair.assetRecipient(), address(0));
        assertEq(getBalance(address(pair)), tokenAmount);

        // verify NFT ownership
        assertEq(test721.ownerOf(1), address(pair));

        // changing spot works as expected
        pair.changeSpotPrice(2 ether);
        assertEq(pair.spotPrice(), 2 ether);
        // changing delta works as expected
        pair.changeDelta(2.2 ether);
        assertEq(pair.delta(), 2.2 ether);
        // // changing fee works as expected
        pair.changeFee(0.2 ether);
        assertEq(pair.fee(), 0.2 ether);
        // (reverts if greater than max fee)
        // changing asset recipient works as expected

        // withdrawing tokens (erc20/721/1155) works as expected

        // withdrawing ETH works as expected

        // need to mock 1155

        // arbitrary call (just call mint on Test721) works as expected
    }

    function testFail_createPair_tradePool_notOwner_changeSpot() public {
        pair.renounceOwnership();
        pair.changeSpotPrice(2 ether);
    }

    function testFail_createPair_tradePool_notOwner_changeDelta() public {
        pair.renounceOwnership();
        pair.changeDelta(2.2 ether);
    }

    function testFail_createPair_tradePool_notOwner_changeFee() public {
        pair.renounceOwnership();
        pair.changeFee(0.2 ether);
    }

    function test_createPair_basic() public {
        uint256[] memory empty;
        this.setupPair{value: modifyInputAmount(tokenAmount)}(
            factory,
            test721,
            bondingCurve,
            delta,
            spotPrice,
            empty,
            tokenAmount,
            address(0)
        );
    }
}
