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
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Test721} from "../../mocks/Test721.sol";
import {TestPairManager} from "../../mocks/TestPairManager.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {LinearCurve} from "../../bonding-curves/LinearCurve.sol";
import {ZeroExRouter2} from "../../ZeroExRouter2.sol";
import {FakeDex} from "../../FakeDex.sol";

contract ZeroExRouterTest is DSTest, ERC721Holder {

  ERC20 testERC20;
  IERC721 test721;
  ICurve bondingCurve;
  LSSVMPairFactory factory;
  LSSVMPair pair;
  ZeroExRouter2 router;
  FakeDex dex;

  uint128 constant MAX_PRICE = 0.1 ether;

  function setUp() public {

        bondingCurve = new LinearCurve();
        testERC20 = ERC20(address(new Test20()));
        test721 = new Test721();
        dex = new FakeDex{value: 0.1 ether}(address(testERC20));
        LSSVMPairEnumerableETH enumerableETHTemplate = new LSSVMPairEnumerableETH();
        LSSVMPairMissingEnumerableETH missingEnumerableETHTemplate = new LSSVMPairMissingEnumerableETH();
        LSSVMPairEnumerableERC20 enumerableERC20Template = new LSSVMPairEnumerableERC20();
        LSSVMPairMissingEnumerableERC20 missingEnumerableERC20Template = new LSSVMPairMissingEnumerableERC20();
        factory = new LSSVMPairFactory(
            enumerableETHTemplate,
            missingEnumerableETHTemplate,
            enumerableERC20Template,
            missingEnumerableERC20Template,
            payable(address(0)),
            0
        );

        factory.setBondingCurveAllowed(bondingCurve, true);
        test721.setApprovalForAll(address(factory), true);
        IERC721Mintable(address(test721)).mint(address(this), 0);
        IMintable(address(testERC20)).mint(address(this), 0.1 ether);
        testERC20.approve(address(factory), 0.1 ether);

        uint256[] memory empty = new uint256[](0);

        pair = factory.createPairERC20(LSSVMPairFactory.CreateERC20PairParams({
          token: testERC20,
          nft: test721,
          bondingCurve: bondingCurve,
          assetRecipient: payable(address(0)),
          poolType: LSSVMPair.PoolType.TRADE,
          delta: 0,
          fee: 0,
          spotPrice: 0.1 ether,
          initialNFTIDs: empty,
          initialTokenBalance: 0.1 ether
        }));

        router = new ZeroExRouter2();
  }

  function testAllTokensToETH() public {
    uint256 originalTokenBalance = testERC20.balanceOf(address(this));
    uint128 price = MAX_PRICE;
    test721.safeTransferFrom(address(this), address(router), 0, abi.encode(address(pair), uint256(0), address(testERC20), address(dex), abi.encodeCall(FakeDex.swap, (price))));
    uint256 afterTokenBalance = testERC20.balanceOf(address(this));
    assertEq(afterTokenBalance-originalTokenBalance, 0);
  } 

  function testMostTokensToETH() public {
    uint256 originalTokenBalance = testERC20.balanceOf(address(this));
    uint128 price = MAX_PRICE * 9 / 10;
    test721.safeTransferFrom(address(this), address(router), 0, abi.encode(address(pair), uint256(0), address(testERC20), address(dex), abi.encodeCall(FakeDex.swap, (price))));
    uint256 afterTokenBalance = testERC20.balanceOf(address(this));
    assertEq(afterTokenBalance-originalTokenBalance, MAX_PRICE - price);
  } 

  receive() external payable {}
}