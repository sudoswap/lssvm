// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ICurve} from "../../bonding-curves/ICurve.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {LSSVMPairETH} from "../../LSSVMPairETH.sol";
import {LSSVMPairERC20} from "../../LSSVMPairERC20.sol";
import {LSSVMPairEnumerableETH} from "../../LSSVMPairEnumerableETH.sol";
import {LSSVMPairMissingEnumerableETH} from "../../LSSVMPairMissingEnumerableETH.sol";
import {LSSVMPairEnumerableERC20} from "../../LSSVMPairEnumerableERC20.sol";
import {LSSVMPairMissingEnumerableERC20} from "../../LSSVMPairMissingEnumerableERC20.sol";
import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Configurable} from "../mixins/Configurable.sol";
import {RouterCaller} from "../mixins/RouterCaller.sol";

abstract contract BaseRouterSinglePoolWithAssetRecipient is
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;
    LSSVMPair sellPair; // Gives NFTs, takes in tokens
    LSSVMPair buyPair; // Takes in NFTs, gives tokens
    address payable constant feeRecipient = payable(address(69));
    address payable constant sellPairRecipient = payable(address(1));
    address payable constant buyPairRecipient = payable(address(2));
    uint256 constant protocolFeeMultiplier = 0;
    uint256 constant numInitialNFTs = 10;

    function setUp() public virtual {
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
        router = new LSSVMRouter(factory, address(0));
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // Setup pair parameters
        uint128 delta = 0 ether;
        uint128 spotPrice = 1 ether;
        uint256[] memory sellIDList = new uint256[](numInitialNFTs);
        uint256[] memory buyIDList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= 2 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
            if (i <= numInitialNFTs) {
                sellIDList[i - 1] = i;
            } else {
                buyIDList[i - numInitialNFTs - 1] = i;
            }
        }

        // Create a sell pool with a spot price of 1 eth, 10 NFTs, and no price increases
        // All stuff gets sent to assetRecipient
        sellPair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            sellPairRecipient,
            LSSVMPair.PoolType.NFT,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            sellIDList,
            10 ether,
            address(router)
        );

        // Create a buy pool with a spot price of 1 eth, 10 NFTs, and no price increases
        // All stuff gets sent to assetRecipient
        buyPair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            buyPairRecipient,
            LSSVMPair.PoolType.TOKEN,
            modifyDelta(uint64(delta)),
            0,
            spotPrice,
            buyIDList,
            10 ether,
            address(router)
        );

        // mint extra NFTs to this contract (i.e. to be held by the caller)
        for (uint256 i = 2 * numInitialNFTs + 1; i <= 3 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }
}
