// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PNMBase} from "./PNMBase.sol";
import {BaseNoArbBondingCurve} from "../../base/BaseNoArbBondingCurve.sol";
import {LSSVMPair} from "../../../LSSVMPair.sol";

abstract contract PNMNoArbBondingCurve is PNMBase, BaseNoArbBondingCurve {
    function setUp() public override {
        super.setUp();
        _initPair();
    }

    function _initPair() internal {
        address owner = address(0x1011);

        uint56 spotPrice = 10 gwei;
        uint64 delta = 10;
        uint8 numItems = 3;

        delete idList;

        vm.startPrank(owner);
        // initialize the pair
        uint256[] memory empty;
        targetPair = setupPair(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
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

        // sell all NFTs minted to the pair
        {
            (
                ,
                uint256 newSpotPrice,
                ,
                uint256 outputAmount,
                uint256 protocolFee
            ) = bondingCurve.getSellInfo(
                    spotPrice,
                    delta,
                    numItems,
                    0,
                    protocolFeeMultiplier
                );

            // give the pair contract enough tokens to pay for the NFTs
            sendTokens(targetPair, outputAmount + protocolFee);

            // sell NFTs
            test721.setApprovalForAll(address(targetPair), true);
            targetPair.swapNFTsForToken(
                idList,
                0,
                payable(address(this)),
                false,
                address(0)
            );
            spotPrice = uint56(newSpotPrice);
        }
        vm.stopPrank();

        useDefaultAgent();
    }
}
