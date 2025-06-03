// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../libraries/LibDiamond.sol";

contract MultiplyFacet {
    function multiply(uint256 num1, uint256 num2) external pure returns (uint256 z) {
        z = num1 * num2; 
    }
}