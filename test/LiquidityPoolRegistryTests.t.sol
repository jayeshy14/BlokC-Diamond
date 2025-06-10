// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../src/registry/LiquidityPoolRegistry.sol";

contract LiquidityPoolRegistryTests is Test {
    LiquidityPoolRegistry public registry;
    address public mockPool1;
    address public mockPool2;
    address public mockPool3;

    function setUp() public {
        registry = new LiquidityPoolRegistry(address(this));
        mockPool1 = address(0x1);
        mockPool2 = address(0x2);
        mockPool3 = address(0x3);
    }

    function testConstructor() public view {
        assertEq(registry.owner(), address(this));
    }

    function testRegisterLiquidityPool() public {
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
        
        assertTrue(registry.isPoolRegistered(mockPool1));
        LiquidityPoolRegistry.LiquidityPool memory pool = registry.getLiquidityPool(mockPool1);
        assertEq(pool.poolAddress, mockPool1);
        assertEq(pool.pairName, "ETH/USDC");
        assertEq(pool.dexId, 1);
    }

    function testRegisterLiquidityPoolTwice() public {
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
        
        vm.expectRevert(LiquidityPoolAlreadyRegistered.selector);
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
    }

    function testRemoveLiquidityPool() public {
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
        
        registry.removeLiquidityPool(mockPool1);
        
        assertFalse(registry.isPoolRegistered(mockPool1));
        vm.expectRevert(LiquidityPoolNotRegistered.selector);
        registry.getLiquidityPool(mockPool1);
    }

    function testRemoveNonExistentPool() public {
        vm.expectRevert(LiquidityPoolNotRegistered.selector);
        registry.removeLiquidityPool(mockPool1);
    }

    function testGetAllLiquidityPools() public {
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
        registry.registerLiquidityPool(2, mockPool2, "BTC/USDT");
        registry.registerLiquidityPool(1, mockPool3, "ETH/USDT");
        
        LiquidityPoolRegistry.LiquidityPool[] memory pools = registry.getAllLiquidityPools();
        assertEq(pools.length, 3);
        
        // Verify pool data
        bool foundPool1 = false;
        bool foundPool2 = false;
        bool foundPool3 = false;
        
        for (uint i = 0; i < pools.length; i++) {
            if (pools[i].poolAddress == mockPool1) {
                assertEq(pools[i].pairName, "ETH/USDC");
                assertEq(pools[i].dexId, 1);
                foundPool1 = true;
            } else if (pools[i].poolAddress == mockPool2) {
                assertEq(pools[i].pairName, "BTC/USDT");
                assertEq(pools[i].dexId, 2);
                foundPool2 = true;
            } else if (pools[i].poolAddress == mockPool3) {
                assertEq(pools[i].pairName, "ETH/USDT");
                assertEq(pools[i].dexId, 1);
                foundPool3 = true;
            }
        }
        
        assertTrue(foundPool1 && foundPool2 && foundPool3);
    }

    function testGetPoolsByDex() public {
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
        registry.registerLiquidityPool(2, mockPool2, "BTC/USDT");
        registry.registerLiquidityPool(1, mockPool3, "ETH/USDT");
        
        LiquidityPoolRegistry.LiquidityPool[] memory dex1Pools = registry.getPoolsByDex(1);
        assertEq(dex1Pools.length, 2);
        
        // Verify DEX 1 pools
        bool foundPool1 = false;
        bool foundPool3 = false;
        
        for (uint i = 0; i < dex1Pools.length; i++) {
            if (dex1Pools[i].poolAddress == mockPool1) {
                assertEq(dex1Pools[i].pairName, "ETH/USDC");
                foundPool1 = true;
            } else if (dex1Pools[i].poolAddress == mockPool3) {
                assertEq(dex1Pools[i].pairName, "ETH/USDT");
                foundPool3 = true;
            }
        }
        
        assertTrue(foundPool1 && foundPool3);
        
        // Test DEX 2 pools
        LiquidityPoolRegistry.LiquidityPool[] memory dex2Pools = registry.getPoolsByDex(2);
        assertEq(dex2Pools.length, 1);
        assertEq(dex2Pools[0].poolAddress, mockPool2);
        assertEq(dex2Pools[0].pairName, "BTC/USDT");
    }

    function testOnlyOwnerCanRegister() public {
        vm.prank(address(0x123));
        vm.expectRevert(NotAuthorized.selector);
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
    }

    function testOnlyOwnerCanRemove() public {
        registry.registerLiquidityPool(1, mockPool1, "ETH/USDC");
        
        vm.prank(address(0x123));
        vm.expectRevert(NotAuthorized.selector);
        registry.removeLiquidityPool(mockPool1);
    }
} 