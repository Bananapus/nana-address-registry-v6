// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice A registry that maps deployed contract addresses to their deployers.
interface IJBAddressRegistry {
    /// @notice Emitted when a contract address is registered.
    /// @param addr The address of the registered contract.
    /// @param deployer The address of the contract's deployer.
    /// @param caller The address that called the register function.
    event AddressRegistered(address indexed addr, address indexed deployer, address caller);

    /// @notice Returns the deployer of a given contract which has been registered.
    /// @param addr The address of the contract to get the deployer of.
    /// @return deployer The deployer of the contract.
    function deployerOf(address addr) external view returns (address deployer);

    /// @notice Register a contract deployed with `create`.
    /// @param deployer The address of the contract's deployer.
    /// @param nonce The nonce used to deploy the contract.
    function registerAddress(address deployer, uint256 nonce) external;

    /// @notice Register a contract deployed with `create2`.
    /// @param deployer The address of the contract's deployer.
    /// @param salt The `create2` salt used to deploy the contract.
    /// @param bytecode The contract's deployment bytecode, including the constructor arguments.
    function registerAddress(address deployer, bytes32 salt, bytes calldata bytecode) external;
}
