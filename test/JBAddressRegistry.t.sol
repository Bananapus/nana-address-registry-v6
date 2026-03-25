// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {JBAddressRegistry} from "../src/JBAddressRegistry.sol";

contract JBAddressRegistryTest is Test {
    event AddressRegistered(address indexed addr, address indexed deployer, address caller);

    address owner = makeAddr("_owner");
    address deployer = makeAddr("_deployer");
    JBAddressRegistry registry;

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    /// @custom:test When registering a pay hook deployed by an EOA, ensure that the transaction is successful, that the
    /// correct event is emitted, and that the hook is added to the mapping.
    function test_addHook_addAddressFromEOA(uint16 nonce) public {
        // Set the nonce of the deployer EOA (if we need to increase it)
        vm.assume(nonce >= vm.getNonce(address(deployer)));
        if (vm.getNonce(address(deployer)) != nonce) {
            vm.setNonce(address(deployer), nonce);
        }

        vm.prank(deployer);
        address mockValidAddress = address(new MockDeployment());

        // Check: is the correct event emitted?
        vm.expectEmit(true, true, true, true);
        emit AddressRegistered(mockValidAddress, deployer, address(this));

        // Test: register the address.
        registry.registerAddress(deployer, nonce);

        // Check: does the address correspond to the correct deployer in the mapping?
        assertTrue(registry.deployerOf(mockValidAddress) == deployer);
    }

    /// @custom:test When registering a pay hook deployed by a contract using `create1`, ensure that the transaction is
    /// successful, that the correct event is emitted, and that the hook is added to the mapping.
    function test_addAddress_addAddressFromContract(uint16 nonce) public {
        Factory factory = new Factory();

        // Set the nonce of the deployer contract (if we need to increase it).
        vm.assume(nonce >= vm.getNonce(address(factory)));
        if (vm.getNonce(address(factory)) != nonce) {
            vm.setNonce(address(factory), nonce);
        }

        // Deploy the new address.
        address mockValidAddress = factory.deploy();

        // Check: is the correct event emitted?
        vm.expectEmit(true, true, true, true);
        emit AddressRegistered(mockValidAddress, address(factory), address(this));

        // Test: register the address.
        registry.registerAddress(address(factory), nonce); // Nonce starts at 1 for contracts

        // Check: does the address correspond to the correct deployer in the mapping?
        assertTrue(registry.deployerOf(mockValidAddress) == address(factory));
    }

    /// @custom:test When registering a pay hook deployed by a contract using `create2`, ensure that the transaction is
    /// successful, that the correct event is emitted, and that the hook is added to the mapping.
    function test_addAddress_addAddressFromContract(bytes32 salt) public {
        vm.assume(salt != bytes32(0));
        Factory factory = new Factory();
        address mockValidAddress = factory.deploy(salt);

        // Check: Is the correct event emitted?
        vm.expectEmit(true, true, true, true);
        emit AddressRegistered(mockValidAddress, address(factory), address(this));

        // Test: register the address.
        registry.registerAddress(address(factory), salt, type(MockDeployment).creationCode);

        // Check: does the address correspond to the correct deployer in the mapping?
        assertTrue(registry.deployerOf(mockValidAddress) == address(factory));
    }
}

// This contract doesn't do much, but is nice.
contract MockDeployment {
    string _stored = "Hello, world!";

    constructor() {}

    function getFancyData() external view returns (string memory) {
        return _stored;
    }
}

contract Factory {
    function deploy() public returns (address) {
        return address(new MockDeployment());
    }

    function deploy(bytes32 _salt) public returns (address) {
        return address(new MockDeployment{salt: _salt}());
    }
}
