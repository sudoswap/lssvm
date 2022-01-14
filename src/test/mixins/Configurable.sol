// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPair} from "../../LSSVMPair.sol";
import {ICurve} from "../../bonding-curves/ICurve.sol";
import {IERC721Mintable} from "../interfaces/IERC721Mintable.sol";
import {LSSVMPairFactory} from "../../LSSVMPairFactory.sol";

abstract contract Configurable {
    function getBalance(address a) public virtual returns (uint256);

    function setupPair(
        LSSVMPairFactory factory,
        IERC721 nft,
        ICurve bondingCurve,
        uint256 delta,
        uint256 spotPrice,
        LSSVMPair.PoolType poolType,
        uint256[] memory _idList,
        uint256 initialTokenBalance,
        address routerAddress /* Yes, this is weird, but due to how we encapsulate state for a Pair's ERC20 token, this is an easy way to set approval for the router.*/
    ) public payable virtual returns (LSSVMPair);

    function setupCurve() public virtual returns (ICurve);

    function setup721() public virtual returns (IERC721Mintable);

    function modifyInputAmount(uint256 inputAmount)
        public
        virtual
        returns (uint256);

    function modifyDelta(uint64 delta) public virtual returns (uint64);

    function modifySpotPrice(uint56 spotPrice) public virtual returns (uint56);

    function sendTokens(LSSVMPair pair, uint256 amount) public virtual;

    function withdrawTokens(LSSVMPair pair) public virtual;

    receive() external payable {}
}
