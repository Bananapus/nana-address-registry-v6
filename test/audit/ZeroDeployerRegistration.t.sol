// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBAddressRegistry} from "src/JBAddressRegistry.sol";

contract ZeroDeployerRegistrationTest is Test {
    JBAddressRegistry internal registry;

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    /// @notice Registering with `address(0)` as the deployer via `create` reverts with `ZeroDeployer`.
    function test_createRegistrationWithZeroDeployerReverts() external {
        uint256 nonce = 1;

        vm.expectRevert(JBAddressRegistry.JBAddressRegistry_ZeroDeployer.selector);
        registry.registerAddress(address(0), nonce);
    }

    /// @notice Registering with `address(0)` as the deployer via `create2` reverts with `ZeroDeployer`.
    function test_create2RegistrationWithZeroDeployerReverts() external {
        bytes32 salt = keccak256("salt");
        bytes memory bytecode = hex"60006000f3";

        vm.expectRevert(JBAddressRegistry.JBAddressRegistry_ZeroDeployer.selector);
        registry.registerAddress(address(0), salt, bytecode);
    }
}
