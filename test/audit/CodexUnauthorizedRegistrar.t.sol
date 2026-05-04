// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

contract CodexUnauthorizedRegistrarTest is Test {
    JBAddressRegistry internal registry;
    address internal deployer = makeAddr("deployer");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    function test_attackerCanFinalizeCreateRegistrationForAnotherDeployersContract() external {
        uint64 nonce = 7;
        vm.setNonce(deployer, nonce);

        vm.prank(deployer);
        address deployed = address(new MockDeployment());

        vm.prank(attacker);
        registry.registerAddress(deployer, nonce);

        assertEq(registry.deployerOf(deployed), deployer, "attacker should be able to write the record");

        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_AlreadyRegistered.selector, deployed)
        );
        registry.registerAddress(deployer, nonce);
    }

    function test_attackerCanFinalizeCreate2RegistrationForAnotherDeployersContract() external {
        Create2Factory factory = new Create2Factory();
        bytes32 salt = keccak256("salt");
        address deployed = factory.deploy(salt);

        vm.prank(attacker);
        registry.registerAddress(address(factory), salt, type(MockDeployment).creationCode);

        assertEq(registry.deployerOf(deployed), address(factory), "attacker should be able to write the record");

        vm.expectRevert(
            abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_AlreadyRegistered.selector, deployed)
        );
        registry.registerAddress(address(factory), salt, type(MockDeployment).creationCode);
    }
}

contract Create2Factory {
    function deploy(bytes32 salt) external returns (address deployed) {
        deployed = address(new MockDeployment{salt: salt}());
    }
}

contract MockDeployment {}
