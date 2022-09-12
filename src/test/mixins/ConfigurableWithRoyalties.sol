// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Configurable, IERC721, LSSVMPair, ICurve, IERC721Mintable, LSSVMPairFactory} from "./Configurable.sol";

import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Test2981} from "../../mocks/Test2981.sol";
import {RoyaltyRegistry} from "manifoldxyz/RoyaltyRegistry.sol";
import {TestRoyaltyRegistry} from "../../mocks/TestRoyaltyRegistry.sol";
import {DSTest} from "ds-test/test.sol";

interface IVM {
    function etch(address where, bytes memory what) external;
}

abstract contract ConfigurableWithRoyalties is Configurable, DSTest {
    address public constant ROYALTY_RECEIVER = address(420);
    uint96 public constant BPS = 30;
    uint96 public constant BASE = 10_000;

    function setup2981() public returns (ERC2981) {
        return ERC2981(new Test2981(ROYALTY_RECEIVER, BPS));
    }

    // royalty registry address is set as constant in the contract
    address constant ROYALTY_REGISTRY =
        0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D;

    function setupRoyaltyRegistry()
        public
        returns (RoyaltyRegistry royaltyRegistry)
    {
        royaltyRegistry = RoyaltyRegistry(new TestRoyaltyRegistry());
        IVM(HEVM_ADDRESS).etch(ROYALTY_REGISTRY, address(royaltyRegistry).code);
        royaltyRegistry = RoyaltyRegistry(ROYALTY_REGISTRY);
        royaltyRegistry.initialize();
    }

    function addRoyalty(uint256 inputAmount)
        public
        pure
        returns (uint256 outputAmount)
    {
        return inputAmount + calcRoyalty(inputAmount);
    }

    function subRoyalty(uint256 inputAmount)
        public
        pure
        returns (uint256 outputAmount)
    {
        return inputAmount - calcRoyalty(inputAmount);
    }

    function calcRoyalty(uint256 inputAmount)
        public
        pure
        returns (uint256 royaltyAmount)
    {
        royaltyAmount = (inputAmount * BPS) / BASE;
    }
}
