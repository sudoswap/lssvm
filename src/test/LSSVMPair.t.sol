// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {LSSVMPair} from "../LSSVMPair.sol";
import {LSSVMPairFactory} from "../LSSVMPairFactory.sol";
import {LinearCurve} from "../bonding-curves/LinearCurve.sol";
import {CurveErrorCodes} from "../bonding-curves/CurveErrorCodes.sol";
import {Test721} from "../mocks/Test721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Hevm} from "./utils/Hevm.sol";

contract LSSVMPairTest is DSTest, ERC721Holder {
    uint256[] idList;
    uint256 startingId;
    Test721 test721;
    LinearCurve linearCurve;
    LSSVMPairFactory factory;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;

    function setUp() public {
        linearCurve = new LinearCurve();
        test721 = new Test721();
        factory = new LSSVMPairFactory(feeRecipient, protocolFeeMultiplier);
    }

    function test_linearCurveSellBuyNoProfit(
        uint56 spotPrice,
        uint56 delta,
        uint8 numItems
    ) public payable {
        if (numItems == 0) {
            return;
        }
        delete idList;
        LSSVMPair pair = new LSSVMPair();
        pair.initialize(
            address(test721),
            address(linearCurve),
            factory,
            LSSVMPair.PoolType.Trade,
            delta,
            0,
            spotPrice
        );
        for (uint256 i = 0; i < numItems; i++) {
            test721.mint(address(this), startingId);
            idList.push(startingId);
            startingId += 1;
        }
        uint256 startBalance;
        uint256 endBalance;
        {
            (
                ,
                uint256 newSpotPrice,
                uint256 outputAmount,
                uint256 protocolFee
            ) = linearCurve.getSellInfo(
                    spotPrice,
                    delta,
                    numItems,
                    0,
                    protocolFeeMultiplier
                );
            payable(address(pair)).transfer(outputAmount + protocolFee);
            IERC721(address(test721)).setApprovalForAll(address(pair), true);
            startBalance = address(this).balance;
            pair.swapNFTsForETH(idList, 0);
            spotPrice = uint56(newSpotPrice);
        }
        {
            (, , uint256 inputAmount, ) = linearCurve.getBuyInfo(
                spotPrice,
                delta,
                numItems,
                0,
                protocolFeeMultiplier
            );
            pair.swapETHForAnyNFTs{value: inputAmount}(idList.length);
            endBalance = address(this).balance;
        }
        assertGeDecimal(startBalance, endBalance, 18);
        pair.withdrawAllETH();
    }

    // function test_linearCurveBuySellNoProfit(
    //   uint8 spotPrice,
    //   uint64 delta,
    //   uint8 numItems
    // ) public payable {
    // }

    receive() external payable {}
}
