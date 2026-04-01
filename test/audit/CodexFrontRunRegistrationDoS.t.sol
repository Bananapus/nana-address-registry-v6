// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBAddressRegistry} from "src/JBAddressRegistry.sol";

contract CodexFrontRunRegistrationDoSTest is Test {
    JBAddressRegistry internal registry;
    MockPostDeployRegistrar internal deployer;

    function setUp() public {
        registry = new JBAddressRegistry();
        deployer = new MockPostDeployRegistrar(registry);
    }

    function test_preRegisteringPredictedCreateAddressRevertsUntilCodeExists() external {
        address predicted = vm.computeCreateAddress(address(deployer), 1);

        vm.prank(makeAddr("attacker"));
        vm.expectRevert(
            abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_AddressNotDeployed.selector, predicted)
        );
        registry.registerAddress(address(deployer), 1);

        assertEq(registry.deployerOf(predicted), address(0), "phantom mapping should not be created");
        assertEq(predicted.code.length, 0, "predicted address should still be undeployed");

        deployer.deployCreate();

        assertGt(predicted.code.length, 0, "deployment should succeed once code exists");
        assertEq(registry.deployerOf(predicted), address(deployer), "post-deploy registration should succeed");
    }

    function test_preRegisteringPredictedCreate2AddressRevertsUntilCodeExists() external {
        bytes32 salt = keccak256("salt");
        bytes32 initCodeHash = keccak256(type(MockHook).creationCode);
        address predicted = vm.computeCreate2Address(salt, initCodeHash, address(deployer));

        vm.prank(makeAddr("attacker"));
        vm.expectRevert(
            abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_AddressNotDeployed.selector, predicted)
        );
        registry.registerAddress(address(deployer), salt, type(MockHook).creationCode);

        assertEq(registry.deployerOf(predicted), address(0), "phantom mapping should not be created");
        assertEq(predicted.code.length, 0, "predicted address should still be undeployed");

        deployer.deployCreate2(salt);

        assertGt(predicted.code.length, 0, "deployment should succeed once code exists");
        assertEq(registry.deployerOf(predicted), address(deployer), "post-deploy registration should succeed");
    }
}

contract MockPostDeployRegistrar {
    JBAddressRegistry internal immutable REGISTRY;
    uint256 internal _nonce;

    constructor(JBAddressRegistry registry) {
        REGISTRY = registry;
    }

    function deployCreate() external returns (address hook) {
        hook = address(new MockHook());
        ++_nonce;
        REGISTRY.registerAddress(address(this), _nonce);
    }

    function deployCreate2(bytes32 salt) external returns (address hook) {
        hook = address(new MockHook{salt: salt}());
        REGISTRY.registerAddress(address(this), salt, type(MockHook).creationCode);
    }
}

contract MockHook {}
