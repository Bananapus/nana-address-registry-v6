// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IJBAddressRegistry} from "./interfaces/IJBAddressRegistry.sol";

/// @notice A public registry that records who deployed a given contract. Anyone can register a contract's deployer,
/// and anyone can look it up — enabling frontend clients and other contracts to verify that a Juicebox hook or
/// extension was deployed by a trusted source.
/// @dev Supports both `create` (deployer + nonce) and `create2` (deployer + salt + bytecode) deployments. The
/// registry computes the expected contract address deterministically and verifies that code exists there before
/// recording the deployer. Each address can only be registered once.
contract JBAddressRegistry is IJBAddressRegistry {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    /// @notice Thrown when attempting to register an address that has already been registered.
    /// @param addr The address that is already registered.
    error JBAddressRegistry_AlreadyRegistered(address addr);

    /// @notice Thrown when a nonce exceeds the maximum value supported by the RLP encoding (uint64 max).
    error JBAddressRegistry_NonceTooLarge(uint256 nonce);

    /// @notice Thrown when attempting to register with `address(0)` as the deployer.
    /// @param deployer The invalid deployer address.
    error JBAddressRegistry_ZeroDeployer(address deployer);

    /// @notice Thrown when attempting to register an address before code exists there.
    /// @param addr The undeployed address being registered.
    error JBAddressRegistry_AddressNotDeployed(address addr);

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Look up who deployed a registered contract. Returns `address(0)` if the contract hasn't been
    /// registered.
    /// @dev Whoever deploys a contract is responsible for registering it.
    /// @custom:param addr The address of the contract to check.
    mapping(address addr => address deployer) public override deployerOf;

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Register a contract that was deployed with `create` (standard deployment). The registry computes the
    /// expected address from the deployer and nonce, then verifies code exists there.
    /// @param deployer The address that deployed the contract.
    /// @param nonce The deployer's transaction nonce at the time of deployment.
    function registerAddress(address deployer, uint256 nonce) external override {
        // Calculate the address of the contract, assuming it was deployed using `create` with the specified nonce.
        address hook = _addressFrom({origin: deployer, nonce: nonce});

        // Register the contract using the calculated address.
        _registerAddress({addr: hook, deployer: deployer});
    }

    /// @notice Register a contract that was deployed with `create2` (deterministic deployment). The registry computes
    /// the expected address from the deployer, salt, and bytecode, then verifies code exists there.
    /// @dev The `create2` salt is determined by the deployer's logic. The deployment bytecode can be retrieved offchain
    /// (from the deployment transaction) or onchain (with `abi.encodePacked(type(deployedContract).creationCode,
    /// abi.encode(constructorArguments))`).
    /// @param deployer The address that deployed the contract.
    /// @param salt The `create2` salt used during deployment.
    /// @param bytecode The full deployment bytecode, including constructor arguments.
    function registerAddress(address deployer, bytes32 salt, bytes calldata bytecode) external override {
        // Calculate the address of the contract using the provided `create2` salt and deployment bytecode.
        address hook =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));

        // Register the contract using the calculated address.
        _registerAddress({addr: hook, deployer: deployer});
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Register a contract's deployer in the `deployerOf` mapping.
    /// @param addr The deployed contract's address.
    /// @param deployer The deployer's address.
    function _registerAddress(address addr, address deployer) internal {
        // The registry only records non-zero deployers.
        if (deployer == address(0)) revert JBAddressRegistry_ZeroDeployer(deployer);
        // The address must already contain runtime code before it can be registered.
        if (addr.code.length == 0) revert JBAddressRegistry_AddressNotDeployed(addr);
        // Each address can only be registered once.
        if (deployerOf[addr] != address(0)) revert JBAddressRegistry_AlreadyRegistered(addr);

        deployerOf[addr] = deployer;

        emit AddressRegistered({addr: addr, deployer: deployer, caller: msg.sender});
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Compute the address of a contract deployed using `create` based on the deployer's address and nonce.
    /// @dev RLP encoding of [origin, nonce]. Supports nonces up to uint64 max (covers any realistic Ethereum nonce).
    /// @dev Adapted from https://ethereum.stackexchange.com/a/87840/68134
    /// @param origin The deployer's address.
    /// @param nonce The nonce used to deploy the contract.
    /// @return addr The computed address of the contract deployed with `create`.
    function _addressFrom(address origin, uint256 nonce) internal pure returns (address addr) {
        if (nonce > type(uint64).max) revert JBAddressRegistry_NonceTooLarge(nonce);

        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, uint8(nonce));
        } else if (nonce <= 0xff) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), origin, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), origin, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), origin, bytes1(0x83), uint24(nonce));
        } else if (nonce <= 0xffffffff) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), origin, bytes1(0x84), uint32(nonce));
        } else if (nonce <= 0xffffffffff) {
            // Nonces above uint32 need 5 payload bytes, so RLP moves to the 0x85 length prefix.
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xdb), bytes1(0x94), origin, bytes1(0x85), uint40(nonce));
        } else if (nonce <= 0xffffffffffff) {
            // Keep extending the nonce payload width as values cross the uint40 boundary.
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xdc), bytes1(0x94), origin, bytes1(0x86), uint48(nonce));
        } else if (nonce <= 0xffffffffffffff) {
            // This branch covers the last intermediate RLP width before the full uint64 payload.
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xdd), bytes1(0x94), origin, bytes1(0x87), uint56(nonce));
        } else {
            // The largest supported CREATE nonce uses the 8-byte uint64 payload with a 0x88 length prefix.
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xde), bytes1(0x94), origin, bytes1(0x88), uint64(nonce));
        }
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 hash = keccak256(data);
        assembly {
            mstore(0, hash)
            addr := mload(0)
        }
    }
}
