// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
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
import {LSSVMRouter2} from "../../LSSVMRouter2.sol";
import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Configurable} from "../mixins/Configurable.sol";
import {RouterCaller} from "../mixins/RouterCaller.sol";
import "../utils/console.sol";

/** Handles test cases where users try to buy multiple NFTs from a pool, but only get partially filled
>  $ forge test --match-contract RPF.*ETH -vvvvv
*/
abstract contract RouterPartialFill is
    DSTest,
    ERC721Holder,
    Configurable,
    RouterCaller
{
    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter2 router;
    LSSVMPair pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 0;
    uint256 numInitialNFTs = 10;
    uint128 SPOT_PRICE;

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
        router = new LSSVMRouter2(factory);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(LSSVMRouter(payable(address(router))), true);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // mint NFT #1-10 to caller
        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }

        // create the pair
        uint256[] memory empty = new uint256[](0);
        (uint128 spotPrice, uint128 delta) = getParamsForPartialFillTest();
        SPOT_PRICE = spotPrice;
        pair = this.setupPair{value: 10 ether}(
            factory,
            test721,
            bondingCurve,
            payable(address(0)),
            LSSVMPair.PoolType.TRADE,
            delta,
            0,
            spotPrice,
            empty,
            10 ether,
            address(router)
        );

        // mint NFTs #11-20 to the pair
        for (uint256 i = numInitialNFTs + 1; i <= numInitialNFTs * 2; i++) {
            test721.mint(address(pair), i);
        }
    }

    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    /**
    Test Properties:
    - Is Buy vs Sell

    If Buy:
    - All items are present vs all items not present
    - All items are within price target vs all items not in price target
    Cases:
    - All items present, all items within price target (normall fill)
    - All items present, not all items within price target (normal partiall fill)
    - Not all items present, all items within price target (restricted partial fill)
    - Not all items present, not all items within price target (restricted-restricted partial fill)
    - (Degenerate case): Whether or not all all items present, no items within price target (should skip)

    If Sell:
    - Enough ETH to cover all items vs not enough ETH to cover all items
    - All items are within price target vs not all items in price target
    Cases:
    - Enough ETH, all items within price target (normall fill)
    - Enough ETH, not all items within price target (normal partial fill)
    - Not enough ETH, all items within price target (restricted partial fill)
    - Not enough ETH, not all items within price target (restricted-restricted partial fill)
    - (Degenerate cases): Not enough ETH to cover even selling one, or no items within price target (should skip)
     */

    // The "base" case where no partial fill is needed, i.e. we buy all of the NFTs
    function test_defaultFullFill() public {
        // Run all cases from 1 to 10
        for (uint256 numNFTs = 1; numNFTs <= 10; numNFTs++) {
            this.setUp();
            uint256 NUM_NFTS = numNFTs;
            uint256 startNFTBalance = test721.balanceOf(address(this));

            // Only 1 pool we're buying from
            LSSVMRouter2.PairSwapSpecificPartialFill[]
                memory buyList = new LSSVMRouter2.PairSwapSpecificPartialFill[](
                    1
                );
            uint256[] memory ids = new uint256[](NUM_NFTS);

            // Get IDS to buy (#11 and onwards)
            for (uint256 i = 1; i <= NUM_NFTS; i++) {
                ids[i - 1] = 10 + i;
            }

            // Get partial fill prices
            uint256[] memory partialFillPrices = router
                .getNFTQuoteForPartialFillBuy(pair, NUM_NFTS);

            // Create the partial fill args
            buyList[0] = LSSVMRouter2.PairSwapSpecificPartialFill({
                swapInfo: LSSVMRouter2.PairSwapSpecific({
                    pair: pair,
                    nftIds: ids
                }),
                expectedSpotPrice: SPOT_PRICE,
                maxCostPerNumNFTs: partialFillPrices
            });

            // Create empty sell list
            LSSVMRouter2.PairSwapSpecificPartialFillForToken[]
                memory emptySellList = new LSSVMRouter2.PairSwapSpecificPartialFillForToken[](
                    0
                );
            string memory UNIMPLEMENTED = "Unimplemented";

            // See if last value of maxCost is the same as getBuyNFTQuote(NUM_NFTS) (they should be equal)
            (, , , uint256 correctQuote, ) = pair.getBuyNFTQuote(NUM_NFTS);
            require(
                correctQuote == partialFillPrices[NUM_NFTS - 1],
                "Incorrect quote"
            );

            // Do the actual partial fill
            try
                this.buyAndSellWithPartialFill{
                    value: partialFillPrices[NUM_NFTS - 1]
                }(router, buyList, emptySellList)
            {
                uint256 endNFTBalance = test721.balanceOf(address(this));
                require(
                    (endNFTBalance - startNFTBalance) == NUM_NFTS,
                    "Too few NFTs acquired"
                );
            } catch Error(string memory reason) {
                if (this.compareStrings(reason, UNIMPLEMENTED)) {
                    return;
                }
            }
        }
    }

    // We buy 1-9 items first, then attempt to partial fill the rest
    // This is a case where:
    // - Not all items are there
    // - Not all items are in price range
    function test_restrictedPartialFill(uint64 delta) public {
        // Set new delta
        pair.changeDelta(this.modifyDelta(delta));

        // First buy 1-9 items (asc), then attempt to partial fill 9-1 items (desc)
        for (
            uint256 numNFTsToBuyFirst = 1;
            numNFTsToBuyFirst <= 9;
            numNFTsToBuyFirst++
        ) {
            this.setUp();

            // Set pseudorandom delta (fuzzing is broken for exp curve for some reason...)
            uint128 newDelta = uint128(
                pair.delta() * numNFTsToBuyFirst * uint256(block.timestamp)
            );
            pair.changeDelta(newDelta);

            // Construct partial fill args first (below we fill some items before doing partial fill)
            LSSVMRouter2.PairSwapSpecificPartialFill[]
                memory buyList = new LSSVMRouter2.PairSwapSpecificPartialFill[](
                    1
                );
            uint256[] memory ids = new uint256[](10);
            // Get all IDs
            for (uint256 i = 1; i <= 10; i++) {
                ids[i - 1] = 10 + i;
            }
            // Get partial fill prices
            uint256[] memory partialFillPrices = router
                .getNFTQuoteForPartialFillBuy(pair, 10);
            // Create the partial fill args
            buyList[0] = LSSVMRouter2.PairSwapSpecificPartialFill({
                swapInfo: LSSVMRouter2.PairSwapSpecific({
                    pair: pair,
                    nftIds: ids
                }),
                expectedSpotPrice: SPOT_PRICE,
                maxCostPerNumNFTs: partialFillPrices
            });
            // Create empty sell list
            LSSVMRouter2.PairSwapSpecificPartialFillForToken[]
                memory emptySellList = new LSSVMRouter2.PairSwapSpecificPartialFillForToken[](
                    0
                );
            string memory UNIMPLEMENTED = "Unimplemented";

            // ** Doing the preeempetive buy **
            // Set IDs to preemptively buy
            uint256[] memory nftIdsToBuyFirst = new uint256[](
                numNFTsToBuyFirst
            );
            for (uint256 i = 1; i <= numNFTsToBuyFirst; i++) {
                nftIdsToBuyFirst[i - 1] = 10 + i;
            }
            (, , , uint256 initialQuote, ) = pair.getBuyNFTQuote(
                numNFTsToBuyFirst
            );
            LSSVMRouter2.RobustPairSwapSpecific[]
                memory initialBuyList = new LSSVMRouter2.RobustPairSwapSpecific[](
                    1
                );
            initialBuyList[0] = LSSVMRouter2.RobustPairSwapSpecific({
                swapInfo: LSSVMRouter2.PairSwapSpecific({
                    pair: pair,
                    nftIds: nftIdsToBuyFirst
                }),
                maxCost: initialQuote
            });
            // Buy these items first (if we can)
            pair.swapTokenForSpecificNFTs{
                value: this.modifyInputAmount(initialQuote)
            }(
                nftIdsToBuyFirst,
                initialQuote,
                address(this),
                false,
                address(this)
            );

            // Get NFT balance now (after the partial fill)
            uint256 startNFTBalance = test721.balanceOf(address(this));

            // Do the actual partial fill
            try
                this.buyAndSellWithPartialFill{value: partialFillPrices[9]}( // We always pass in the maximal amount of ETH possible, we should get a refund
                    router,
                    buyList,
                    emptySellList
                )
            returns (uint256 remainingValue) {
                uint256 endNFTBalance = test721.balanceOf(address(this));
                uint256 numNFTsAcquired = endNFTBalance - startNFTBalance;
                if (numNFTsAcquired > 0) {
                    uint256 amountPaid = partialFillPrices[9] - remainingValue;
                    uint256 maxBudget = partialFillPrices[numNFTsAcquired - 1];
                    if (amountPaid > maxBudget) {
                        console.log(numNFTsAcquired);
                        console.log(amountPaid);
                        console.log(maxBudget);
                    }
                    require(amountPaid <= maxBudget, "Overpaid");
                } else {
                    require(
                        remainingValue == partialFillPrices[9],
                        "Price leakage"
                    );
                }
            } catch Error(string memory reason) {
                if (this.compareStrings(reason, UNIMPLEMENTED)) {
                    return;
                }
            }
        }
    }

    // All items present, not all items buyable
    function test_partialFill(uint64 delta) public {
        // Set new delta
        pair.changeDelta(this.modifyDelta(delta));

        // First buy 1-9 items (asc), then attempt to partial fill 9-1 items (desc)
        for (
            uint256 numNFTsToBuyFirst = 1;
            numNFTsToBuyFirst <= 9;
            numNFTsToBuyFirst++
        ) {
            this.setUp();

            // Construct partial fill args first (below we fill some items before doing partial fill)
            LSSVMRouter2.PairSwapSpecificPartialFill[]
                memory buyList = new LSSVMRouter2.PairSwapSpecificPartialFill[](
                    1
                );
            uint256[] memory ids = new uint256[](10);
            // Get all IDs
            for (uint256 i = 1; i <= 10; i++) {
                ids[i - 1] = 10 + i;
            }
            // Get partial fill prices
            uint256[] memory partialFillPrices = router
                .getNFTQuoteForPartialFillBuy(pair, 10);
            // Create the partial fill args
            buyList[0] = LSSVMRouter2.PairSwapSpecificPartialFill({
                swapInfo: LSSVMRouter2.PairSwapSpecific({
                    pair: pair,
                    nftIds: ids
                }),
                expectedSpotPrice: SPOT_PRICE,
                maxCostPerNumNFTs: partialFillPrices
            });
            // Create empty sell list
            LSSVMRouter2.PairSwapSpecificPartialFillForToken[]
                memory emptySellList = new LSSVMRouter2.PairSwapSpecificPartialFillForToken[](
                    0
                );
            string memory UNIMPLEMENTED = "Unimplemented";

            // ** Set spor price to be updated as if numNFTSToBuyFirst got bought **
            (, uint256 newSpotPrice, , , ) = pair.getBuyNFTQuote(
                numNFTsToBuyFirst
            );
            pair.changeSpotPrice(uint128(newSpotPrice));

            // Get NFT balance now (after the partial fill)
            uint256 startNFTBalance = test721.balanceOf(address(this));

            // Do the actual partial fill
            try
                // We always pass in the maximal amount of ETH possible, we should get a refund
                this.buyAndSellWithPartialFill{value: partialFillPrices[9]}(
                    router,
                    buyList,
                    emptySellList
                )
            returns (uint256 remainingValue) {
                uint256 endNFTBalance = test721.balanceOf(address(this));
                uint256 numNFTsAcquired = endNFTBalance - startNFTBalance;
                if (numNFTsAcquired > 0) {
                    uint256 amountPaid = partialFillPrices[9] - remainingValue;
                    uint256 maxBudget = partialFillPrices[numNFTsAcquired - 1];
                    if (amountPaid > maxBudget) {
                        console.log(numNFTsAcquired);
                        console.log(amountPaid);
                        console.log(maxBudget);
                    }
                    require(amountPaid <= maxBudget, "Overpaid");
                } else {
                    require(
                        remainingValue == partialFillPrices[9],
                        "Price leakage"
                    );
                }
            } catch Error(string memory reason) {
                if (this.compareStrings(reason, UNIMPLEMENTED)) {
                    return;
                }
            }
        }
    }

    // Price is within range, not all items buyable
    function test_partialFillMissingItems(uint64 delta) public {
        // Set new delta
        pair.changeDelta(this.modifyDelta(delta));

        // First buy 1-9 items (asc), then attempt to partial fill 9-1 items (desc)
        for (
            uint256 numNFTsToBuyFirst = 1;
            numNFTsToBuyFirst <= 9;
            numNFTsToBuyFirst++
        ) {
            this.setUp();

            // Construct partial fill args first (below we fill some items before doing partial fill)
            LSSVMRouter2.PairSwapSpecificPartialFill[]
                memory buyList = new LSSVMRouter2.PairSwapSpecificPartialFill[](
                    1
                );
            uint256[] memory ids = new uint256[](10);

            // Set IDs to be inconsistent with the actual inventory state (for partial fill)
            for (uint256 i = 1; i <= 10; i++) {
                ids[i - 1] = 10 + i - numNFTsToBuyFirst;
            }
            // Get partial fill prices
            uint256[] memory partialFillPrices = router
                .getNFTQuoteForPartialFillBuy(pair, 10);
            // Create the partial fill args
            buyList[0] = LSSVMRouter2.PairSwapSpecificPartialFill({
                swapInfo: LSSVMRouter2.PairSwapSpecific({
                    pair: pair,
                    nftIds: ids
                }),
                expectedSpotPrice: SPOT_PRICE-1,
                maxCostPerNumNFTs: partialFillPrices
            });
            // Create empty sell list
            LSSVMRouter2.PairSwapSpecificPartialFillForToken[]
                memory emptySellList = new LSSVMRouter2.PairSwapSpecificPartialFillForToken[](
                    0
                );
            string memory UNIMPLEMENTED = "Unimplemented";

            // Get NFT balance now (after the partial fill)
            uint256 startNFTBalance = test721.balanceOf(address(this));

            // Do the actual partial fill
            try
                // We always pass in the maximal amount of ETH possible, we should get a refund
                this.buyAndSellWithPartialFill{value: partialFillPrices[9]}(
                    router,
                    buyList,
                    emptySellList
                )
            returns (uint256 remainingValue) {
                uint256 endNFTBalance = test721.balanceOf(address(this));
                uint256 numNFTsAcquired = endNFTBalance - startNFTBalance;
                if (numNFTsAcquired > 0) {
                    uint256 amountPaid = partialFillPrices[9] - remainingValue;
                    uint256 maxBudget = partialFillPrices[numNFTsAcquired - 1];
                    if (amountPaid > maxBudget) {
                        console.log(numNFTsAcquired);
                        console.log(amountPaid);
                        console.log(maxBudget);
                    }
                    require(amountPaid <= maxBudget, "Overpaid");
                } else {
                    require(
                        remainingValue == partialFillPrices[9],
                        "Price leakage"
                    );
                }
            } catch Error(string memory reason) {
                if (this.compareStrings(reason, UNIMPLEMENTED)) {
                    return;
                }
            }
        }
    }
}
