// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICapacityRegistry} from "../interfaces/ICapacityRegistry.sol";

// Mock interfaces for Uniswap v4 concepts
interface IPoolManager {
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }
}

struct PoolKey {
    address currency0; // e.g. Synthetic Obligation (Base Unit of Account)
    address currency1; // e.g. Synthetic Service Token (representing Service S at Time Slot T)
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

library PoolIdLibrary {
    function toId(PoolKey calldata key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }
}

/**
 * @title CapacityGateHook
 * @notice A conceptual Uniswap v4 hook that intercepts swaps to enforce a shared capacity constraint
 * across service- and datetime-specific pools (independent of specific providers to enable price exploration).
 */
contract CapacityGateHook {
    using PoolIdLibrary for PoolKey;

    ICapacityRegistry public immutable capacityRegistry;
    
    // Maps a pool ID to its specific Service and Time Slot metadata
    mapping(bytes32 => PoolMetadata) public poolMetadata;

    struct PoolMetadata {
        uint256 serviceId;
        uint256 slotId;
        uint256 capacityPerToken; // amount of raw capacity units consumed per service token swapped
    }

    event PoolRegistered(bytes32 indexed poolId, uint256 indexed serviceId, uint256 indexed slotId);

    constructor(ICapacityRegistry _capacityRegistry) {
        capacityRegistry = _capacityRegistry;
    }

    /**
     * @notice Register metadata for a new service/slot pool in the hook.
     */
    function registerPoolMetadata(
        PoolKey calldata key,
        uint256 serviceId,
        uint256 slotId,
        uint256 capacityPerToken
    ) external {
        bytes32 poolId = key.toId();
        poolMetadata[poolId] = PoolMetadata({
            serviceId: serviceId,
            slotId: slotId,
            capacityPerToken: capacityPerToken
        });
        emit PoolRegistered(poolId, serviceId, slotId);
    }

    /**
     * @notice Uniswap v4 Hook callback executed before a swap occurs.
     * Attributes capacity consumption to the specific provider(s) whose tick ranges are crossed.
     */
    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external returns (bytes4) {
        PoolMetadata memory meta = poolMetadata[key.toId()];
        
        // Skip validation if the pool is not registered
        if (meta.serviceId == 0) {
            return this.beforeSwap.selector;
        }

        // zeroForOne represents swapping Synthetic Obligations for Service Capacity SFTs
        if (params.zeroForOne) { 
            uint256 tokenAmount = params.amountSpecified < 0 
                ? uint256(-params.amountSpecified) 
                : uint256(params.amountSpecified);
                
            uint256 requiredCapacity = tokenAmount * meta.capacityPerToken;

            // Note: In production, the hook would inspect the tick transitions of the swap
            // to identify WHICH providers' positions are being crossed, then query and decrement
            // their specific capacity in the capacityRegistry.
            
            // Example conceptual loop for single active provider at current tick:
            address activeProvider = _getActiveProviderAtCurrentTick(key);
            uint256 available = capacityRegistry.getCapacity(activeProvider, meta.slotId);
            
            if (available < requiredCapacity) {
                revert("RWS: Insufficient capacity for active provider in this price range");
            }
            
            capacityRegistry.consumeCapacity(activeProvider, meta.slotId, requiredCapacity);
        }

        return this.beforeSwap.selector;
    }

    /**
     * @dev Conceptual helper to determine which provider's liquidity range is active at the current pool tick.
     */
    function _getActiveProviderAtCurrentTick(PoolKey calldata key) internal view returns (address) {
        // Retrieve current tick from PoolManager and map it to the provider who registered that tick range
        return address(0x123); // Mock provider address
    }
}
