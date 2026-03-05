// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/JBAddressRegistry.sol";

contract JBAddressRegistryTest_Fork is Test {
    address owner = makeAddr("_owner");
    address deployer = makeAddr("_deployer");

    uint256 blockHeight = 17_580_288;

    JBAddressRegistry registry;

    function setUp() public {
        // Skip fork tests when the RPC URL is not available (e.g. in CI).
        string memory rpcUrl = vm.envOr("RPC_ETHEREUM_MAINNET", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true);
        }

        // Start a mainnet fork.
        vm.createSelectFork(vm.rpcUrl("ethereum"), blockHeight);

        registry = new JBAddressRegistry();
    }

    /// @custom:test Make sure adding a new hook works for both `create1` and `create2`.
    function test_integration_newDeployments() public {
        // Deploy a `MockDeployment` factory.
        Factory factory = new Factory();

        // Deploy from an EOA.
        vm.prank(deployer);
        address mockContract = address(new MockDeployment());

        // `create1` from the factory.
        address mockDeployment1 = factory.deploy();

        // `create2` from the factory.
        address mockDeployment2 = factory.deploy(keccak256(abi.encode(696_969)));

        // Register the EOA (nonce 0 from the EOA).
        registry.registerAddress(deployer, 0);

        // Register the `create1` deployment (nonce 1 from the factory).
        registry.registerAddress(address(factory), 1);

        // Register the `create2` deployment using the salt above.
        registry.registerAddress(address(factory), keccak256(abi.encode(696_969)), type(MockDeployment).creationCode);

        // Check: EOA?
        assertEq(registry.deployerOf(mockContract), deployer);

        // Check: `create1` deployment?
        assertEq(registry.deployerOf(mockDeployment1), address(factory));

        // Check: `create2` deployment?
        assertEq(registry.deployerOf(mockDeployment2), address(factory));
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
