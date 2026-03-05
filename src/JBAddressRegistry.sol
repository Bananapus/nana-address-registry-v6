// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IJBAddressRegistry} from "./interfaces/IJBAddressRegistry.sol";

/// @notice Frontend clients need a way to verify that a Juicebox contract has a deployer they trust. `JBAddressRegistry`
/// allows any contract deployed with `create` or `create2` to publicly register its deployer's address. Whoever deploys
/// a contract is responsible for registering it.
/// @dev `JBAddressRegistry` is intended for registering the deployers of Juicebox pay/redeem hooks, but does not
/// enforce adherence to an interface, and can be used for any `create`/`create2` deployer.
/// @dev The addresses of the deployed contracts are computed deterministically based on the deployer's address, and a
/// nonce (for `create`) or `create2` salt and deployment bytecode (for `create2`).
contract JBAddressRegistry is IJBAddressRegistry {
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Returns the deployer of a given contract which has been registered.
    /// @dev Whoever deploys a contract is responsible for registering it.
    /// @custom:param addr The address of the contract to get the deployer of.
    mapping(address addr => address deployer) public override deployerOf;

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Register a deployed contract's address.
    /// @dev The contract must be deployed using `create`.
    /// @param deployer The address of the contract's deployer.
    /// @param nonce The nonce used to deploy the contract.
    function registerAddress(address deployer, uint256 nonce) external override {
        // Calculate the address of the contract, assuming it was deployed using `create` with the specified nonce.
        address hook = _addressFrom(deployer, nonce);

        // Register the contract using the calculated address.
        _registerAddress(hook, deployer);
    }

    /// @notice Register a deployed contract's address.
    /// @dev The contract must be deployed using `create2`.
    /// @dev The `create2` salt is determined by the deployer's logic. The deployment bytecode can be retrieved offchain
    /// (from the deployment transaction) or onchain (with `abi.encodePacked(type(deployedContract).creationCode,
    /// abi.encode(constructorArguments))`).
    /// @param deployer The address of the contract's deployer.
    /// @param salt The `create2` salt used to deploy the contract.
    /// @param bytecode The contract's deployment bytecode, including the constructor arguments.
    function registerAddress(address deployer, bytes32 salt, bytes calldata bytecode) external override {
        // Calculate the address of the contract using the provided `create2` salt and deployment bytecode.
        address hook =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));

        // Register the contract using the calculated address.
        _registerAddress(hook, deployer);
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Compute the address of a contract deployed using `create` based on the deployer's address and nonce.
    /// @dev Taken from https://ethereum.stackexchange.com/a/87840/68134 - this won't work for nonces > 2**32. If
    /// you reach that nonce please: 1) ping us, because wow 2) use another deployer.
    /// @param origin The deployer's address.
    /// @param nonce The nonce used to deploy the contract.
    function _addressFrom(address origin, uint256 nonce) internal pure returns (address addr) {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), origin, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), origin, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), origin, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), origin, bytes1(0x84), uint32(nonce));
        }
        bytes32 hash = keccak256(data);
        assembly {
            mstore(0, hash)
            addr := mload(0)
        }
    }

    /// @notice Register a contract's deployer in the `deployerOf` mapping.
    /// @param addr The deployed contract's address.
    /// @param deployer The deployer's address.
    function _registerAddress(address addr, address deployer) internal {
        deployerOf[addr] = deployer;

        emit AddressRegistered({addr: addr, deployer: deployer, caller: msg.sender});
    }
}
