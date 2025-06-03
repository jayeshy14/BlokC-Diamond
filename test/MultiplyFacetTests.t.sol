// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TestStates.sol";
import "../src/facets/MultiplyFacet.sol";

contract TestMultiplyFacet is StateDeployMultiplyFacet {
    function testMultiplyBasic() public view{
        uint256 result = MultiplyFacet(address(diamond)).multiply(2, 3);
        assertEq(result, 6);
    }

    function testMultiplyWithZero() public view {
        uint256 result = MultiplyFacet(address(diamond)).multiply(0, 5);
        assertEq(result, 0);
    }

    function testMultiplyWithLargeNumbers() public view {
        uint256 result = MultiplyFacet(address(diamond)).multiply(1000, 1000);
        assertEq(result, 1000000);
    }

    function testMultiplyWithMaxUint256() public view {
        uint256 result = MultiplyFacet(address(diamond)).multiply(type(uint256).max, 1);
        assertEq(result, type(uint256).max);
    }

    function testMultiplyWithSameNumbers() public view {
        uint256 result = MultiplyFacet(address(diamond)).multiply(7, 7);
        assertEq(result, 49);
    }
} 