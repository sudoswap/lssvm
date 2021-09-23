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
        LSSVMPair pairTemplate = new LSSVMPair();
        factory = new LSSVMPairFactory(
            pairTemplate,
            feeRecipient,
            protocolFeeMultiplier
        );
    }

    /**
    @dev Ensures selling NFTs & buying them back results in no profit.
     */
    function test_linearCurveSellBuyNoProfit(
        uint56 spotPrice,
        uint56 delta,
        uint8 numItems
    ) public payable {
        // decrease the range of numItems to speed up testing
        numItems = numItems % 4;

        if (numItems == 0) {
            return;
        }

        delete idList;

        // initialize the pair
        uint256[] memory empty;
        LSSVMPair pair = factory.createPair(
            test721,
            linearCurve,
            LSSVMPair.PoolType.Trade,
            delta,
            0,
            spotPrice,
            empty
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
                uint256 outputAmount,
                uint256 protocolFee
            ) = linearCurve.getSellInfo(
                    spotPrice,
                    delta,
                    numItems,
                    0,
                    protocolFeeMultiplier
                );

            // give the pair contract enough ETH to pay for the NFTs
            payable(address(pair)).transfer(outputAmount + protocolFee);

            // sell NFTs
            IERC721(address(test721)).setApprovalForAll(address(pair), true);
            startBalance = address(this).balance;
            pair.swapNFTsForETH(idList, 0);
            spotPrice = uint56(newSpotPrice);
        }

        // buy back the NFTs just sold to the pair
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

        // ensure the caller didn't profit from the aggregate trade
        assertGeDecimal(startBalance, endBalance, 18);

        // withdraw the ETH in the pair back
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
