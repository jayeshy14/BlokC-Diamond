// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error NotAuthorized();
error LiquidityPoolAlreadyRegistered();
error LiquidityPoolNotRegistered();

contract LiquidityPoolRegistry {
    struct LiquidityPool {
        address poolAddress;
        string pairName;
        uint256 dexId;
    }

    address public immutable owner;
    
    // Mapping from pool address to its data
    mapping(address => LiquidityPool) public pools;
    // Array of all registered pool addresses
    address[] public registeredPools;
    // Mapping to check if pool is registered
    mapping(address => bool) public isPoolRegistered;

    event LiquidityPoolRegisteredFromRegistry(address indexed poolAddress, uint256 dexId);
    event LiquidityPoolRemovedFromRegistry(address indexed poolAddress, uint256 dexId);

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    function registerLiquidityPool(uint256 _dexId, address _poolAddress, string memory _pairName) external onlyOwner {
        if (isPoolRegistered[_poolAddress]) revert LiquidityPoolAlreadyRegistered();
        
        pools[_poolAddress] = LiquidityPool({
            poolAddress: _poolAddress,
            pairName: _pairName,
            dexId: _dexId
        });
        
        registeredPools.push(_poolAddress);
        isPoolRegistered[_poolAddress] = true;
        
        emit LiquidityPoolRegisteredFromRegistry(_poolAddress, _dexId);
    }

    function removeLiquidityPool(address _poolAddress) external onlyOwner {
        if (!isPoolRegistered[_poolAddress]) revert LiquidityPoolNotRegistered();
        
        // Remove from registered pools array
        for (uint256 i = 0; i < registeredPools.length; i++) {
            if (registeredPools[i] == _poolAddress) {
                registeredPools[i] = registeredPools[registeredPools.length - 1];
                registeredPools.pop();
                break;
            }
        }
        
        uint256 dexId = pools[_poolAddress].dexId;
        delete pools[_poolAddress];
        isPoolRegistered[_poolAddress] = false;
        
        emit LiquidityPoolRemovedFromRegistry(_poolAddress, dexId);
    }

    function getLiquidityPool(address _poolAddress) external view returns (LiquidityPool memory) {
        if (!isPoolRegistered[_poolAddress]) revert LiquidityPoolNotRegistered();
        return pools[_poolAddress];
    }

    function getAllLiquidityPools() external view returns (LiquidityPool[] memory) {
        LiquidityPool[] memory allPools = new LiquidityPool[](registeredPools.length);
        for (uint256 i = 0; i < registeredPools.length; i++) {
            allPools[i] = pools[registeredPools[i]];
        }
        return allPools;
    }

    function getPoolsByDex(uint256 _dexId) external view returns (LiquidityPool[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < registeredPools.length; i++) {
            if (pools[registeredPools[i]].dexId == _dexId) {
                count++;
            }
        }
        
        LiquidityPool[] memory dexPools = new LiquidityPool[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < registeredPools.length; i++) {
            if (pools[registeredPools[i]].dexId == _dexId) {
                dexPools[index] = pools[registeredPools[i]];
                index++;
            }
        }
        return dexPools;
    }
}