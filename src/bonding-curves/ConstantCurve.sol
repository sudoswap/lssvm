// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

contract ConstantCurve {

  function increasePrice(uint256 spotPrice, uint256 delta) external returns (uint256) {
    return delta;
  }

  function decreasePrice(uint256 spotPrice, uint256 delta) external returns (uint256) {
    return delta;
  }
}