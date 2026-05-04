// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice A registry that maps deployed contract addresses to their deployers, allowing anyone to verify who deployed
/// a given contract. Primarily used to verify the trustworthiness of Juicebox hooks and extensions.
interface IJBAddressRegistry {
    /// @notice Emitted when a contract's deployer is registered.
    /// @param addr The address of the registered contract.
    /// @param deployer The address that deployed the contract.
    /// @param caller The address that called the register function.
    event AddressRegistered(address indexed addr, address indexed deployer, address caller);

    /// @notice Look up who deployed a registered contract.
    /// @param addr The address of the contract to check.
    /// @return deployer The address that deployed the contract, or `address(0)` if not registered.
    function deployerOf(address addr) external view returns (address deployer);

    /// @notice Register a contract that was deployed with `create` (standard deployment).
    /// @param deployer The address that deployed the contract.
    /// @param nonce The deployer's transaction nonce at the time of deployment.
    function registerAddress(address deployer, uint256 nonce) external;

    /// @notice Register a contract that was deployed with `create2` (deterministic deployment).
    /// @param deployer The address that deployed the contract.
    /// @param salt The `create2` salt used during deployment.
    /// @param bytecode The full deployment bytecode, including constructor arguments.
    function registerAddress(address deployer, bytes32 salt, bytes calldata bytecode) external;
}
