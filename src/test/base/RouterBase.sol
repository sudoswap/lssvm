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
import {LSSVMRouter} from "../../LSSVMRouter.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {Configurable} from "../mixins/Configurable.sol";

abstract contract RouterBase is DSTest, ERC721Holder, Configurable {

    IERC721Mintable test721;
    ICurve bondingCurve;
    LSSVMPairFactory factory;
    LSSVMRouter router;
    LSSVMPair pair;
    address payable constant feeRecipient = payable(address(69));
    uint256 constant protocolFeeMultiplier = 3e15;

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
        router = new LSSVMRouter(factory);
        factory.setBondingCurveAllowed(bondingCurve, true);
        factory.setRouterAllowed(router, true);

        // set NFT approvals
        test721.setApprovalForAll(address(factory), true);
        test721.setApprovalForAll(address(router), true);

        // Setup pair parameters
        uint256 delta = 0 ether;
        uint256 spotPrice = 1 ether;
        uint256 numInitialNFTs = 10;
        uint256[] memory idList = new uint256[](numInitialNFTs);
        for (uint256 i = 1; i <= numInitialNFTs; i++) {
            test721.mint(address(this), i);
            idList[i - 1] = i;
        }
        pair = this.setupPair{value: modifyInputAmount(10 ether)}(
            factory,
            test721,
            bondingCurve,
            modifyDelta(uint64(delta)),
            spotPrice,
            idList,
            10 ether,
            address(router)
        );

        // mint extra NFTs to this contract
        for (uint256 i = numInitialNFTs + 1; i <= 2 * numInitialNFTs; i++) {
            test721.mint(address(this), i);
        }
    }

    function test_swapTokenForSingleAnyNFT() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 1});
        this.swapTokenForAnyNFTs{value: modifyInputAmount(1.11 ether)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            1.11 ether
        );
    }

    function test_swapTokenForSingleSpecificNFT() public {
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        this.swapTokenForSpecificNFTs{value: modifyInputAmount(1.11 ether)}(
            router,
            swapList,
            payable(address(this)),
            address(this),
            block.timestamp,
            1.11 ether
        );
    }

    function test_swapSingleNFTForToken() public {
        uint256 numInitialNFTs = 10;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = numInitialNFTs + 1;
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
    }

    // function test_swapSingleNFTForAnyNFT() public {
    //     uint256 numInitialNFTs = 10;

    //     // construct NFT to ETH swap list
    //     uint256[] memory sellNFTIds = new uint256[](1);
    //     sellNFTIds[0] = numInitialNFTs + 1;
    //     LSSVMRouter.PairSwapSpecific[]
    //         memory nftToETHSwapList = new LSSVMRouter.PairSwapSpecific[](1);
    //     nftToETHSwapList[0] = LSSVMRouter.PairSwapSpecific({
    //         pair: pair,
    //         nftIds: sellNFTIds
    //     });

    //     // construct ETH to NFT swap list
    //     LSSVMRouter.PairSwapAny[]
    //         memory ethToNFTSwapList = new LSSVMRouter.PairSwapAny[](1);
    //     ethToNFTSwapList[0] = LSSVMRouter.PairSwapAny({
    //         pair: pair,
    //         numItems: 1
    //     });

    //     router.swapNFTsForAnyNFTsThroughETH{value: 1 ether}(
    //         LSSVMRouter.NFTsForAnyNFTsTrade({
    //             nftToTokenTrades: nftToETHSwapList,
    //             tokenToNFTTrades: ethToNFTSwapList
    //         }),
    //         0,
    //         payable(address(this)),
    //         address(this),
    //         block.timestamp
    //     );
    // }

    // function test_swapSingleNFTForSpecificNFT() public {
    //     uint256 numInitialNFTs = 10;

    //     // construct NFT to ETH swap list
    //     uint256[] memory sellNFTIds = new uint256[](1);
    //     sellNFTIds[0] = numInitialNFTs + 1;
    //     LSSVMRouter.PairSwapSpecific[]
    //         memory nftToETHSwapList = new LSSVMRouter.PairSwapSpecific[](1);
    //     nftToETHSwapList[0] = LSSVMRouter.PairSwapSpecific({
    //         pair: pair,
    //         nftIds: sellNFTIds
    //     });

    //     // construct ETH to NFT swap list
    //     uint256[] memory buyNFTIds = new uint256[](1);
    //     buyNFTIds[0] = 1;
    //     LSSVMRouter.PairSwapSpecific[]
    //         memory ethToNFTSwapList = new LSSVMRouter.PairSwapSpecific[](1);
    //     ethToNFTSwapList[0] = LSSVMRouter.PairSwapSpecific({
    //         pair: pair,
    //         nftIds: buyNFTIds
    //     });

    //     router.swapNFTsForSpecificNFTsThroughETH{value: 1 ether}(
    //         LSSVMRouter.NFTsForSpecificNFTsTrade({
    //             nftToTokenTrades: nftToETHSwapList,
    //             tokenToNFTTrades: ethToNFTSwapList
    //         }),
    //         0,
    //         payable(address(this)),
    //         address(this),
    //         block.timestamp
    //     );
    // }

    function test_swapTokenfor5NFTs() public {
        LSSVMRouter.PairSwapAny[]
            memory swapList = new LSSVMRouter.PairSwapAny[](1);
        swapList[0] = LSSVMRouter.PairSwapAny({pair: pair, numItems: 5});
        uint256 startBalance = test721.balanceOf(address(this));
        this.swapTokenForAnyNFTs(
            router, 
            swapList, 
            payable(address(this)), 
            address(this), 
            block.timestamp, 
            7 ether);
        uint256 endBalance = test721.balanceOf(address(this));
        require((endBalance - startBalance) == 5, "Too few NFTs acquired");
    }

    function test_swap5NFTsForToken() public {
        uint256 numInitialNFTs = 10;
        uint256[] memory nftIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nftIds[i] = numInitialNFTs + i + 1;
        }
        LSSVMRouter.PairSwapSpecific[]
            memory swapList = new LSSVMRouter.PairSwapSpecific[](1);
        swapList[0] = LSSVMRouter.PairSwapSpecific({
            pair: pair,
            nftIds: nftIds
        });
        router.swapNFTsForToken(
            swapList,
            0.9 ether,
            payable(address(this)),
            block.timestamp
        );
    }

    function swapTokenForAnyNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapAny[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);

    function swapTokenForSpecificNFTs(
        LSSVMRouter router,
        LSSVMRouter.PairSwapSpecific[] calldata swapList,
        address payable ethRecipient,
        address nftRecipient,
        uint256 deadline,
        uint256 inputAmount
    ) public payable virtual returns (uint256);
}
