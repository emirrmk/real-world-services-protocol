// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICapacityRegistry {
    event CapacityUpdated(address indexed provider, uint256 indexed slot, uint256 newCapacity);
    event CapacityConsumed(address indexed provider, uint256 indexed slot, uint256 amount);
    event CapacityReleased(address indexed provider, uint256 indexed slot, uint256 amount);

    /**
     * @notice Set the total physical capacity for a specific provider and time slot.
     * @param slot The time-slot ID.
     * @param capacity The raw capacity units available.
     */
    function setCapacity(uint256 slot, uint256 capacity) external;

    /**
     * @notice Consume a unit of capacity. Called by authorized hooks during swaps.
     * @param provider The address of the service provider.
     * @param slot The time-slot ID.
     * @param amount The amount of capacity to consume.
     */
    function consumeCapacity(address provider, uint256 slot, uint256 amount) external;

    /**
     * @notice Re-expose capacity (e.g., if a service is cancelled or predecessor fails validation).
     * @param provider The address of the service provider.
     * @param slot The time-slot ID.
     * @param amount The amount of capacity to release.
     */
    function releaseCapacity(address provider, uint256 slot, uint256 amount) external;

    /**
     * @notice Get available capacity.
     * @param provider The address of the service provider.
     * @param slot The time-slot ID.
     * @return The remaining capacity units.
     */
    function getCapacity(address provider, uint256 slot) external view returns (uint256);
}
