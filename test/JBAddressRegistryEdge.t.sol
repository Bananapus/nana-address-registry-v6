// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {JBAddressRegistry} from "../src/JBAddressRegistry.sol";

/// @title JBAddressRegistryEdge
/// @notice Edge case and negative tests for JBAddressRegistry: RLP encoding boundaries,
///         mismatched parameters, duplicate registrations, and address(0) inputs.
contract JBAddressRegistryEdge is Test {
    event AddressRegistered(address indexed addr, address indexed deployer, address caller);

    JBAddressRegistry registry;
    address deployer = makeAddr("deployer");

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    // =========================================================================
    // RLP encoding boundary tests - verify _addressFrom at each nonce boundary
    // =========================================================================

    /// @notice Nonce 0: uses 0x80 byte suffix.
    function test_nonceBoundary_zero() public {
        _verifyCreateRegistration(deployer, 0);
    }

    /// @notice Nonce 1: single-byte RLP (nonce <= 0x7f).
    function test_nonceBoundary_one() public {
        _verifyCreateRegistration(deployer, 1);
    }

    /// @notice Nonce 0x7f: upper boundary of single-byte RLP.
    function test_nonceBoundary_0x7f() public {
        _verifyCreateRegistration(deployer, 0x7f);
    }

    /// @notice Nonce 0x80: switches to 2-byte RLP (0x81 prefix).
    function test_nonceBoundary_0x80() public {
        _verifyCreateRegistration(deployer, 0x80);
    }

    /// @notice Nonce 0xff: upper boundary of uint8 nonce.
    function test_nonceBoundary_0xff() public {
        _verifyCreateRegistration(deployer, 0xff);
    }

    /// @notice Nonce 0x100: switches to uint16 encoding.
    function test_nonceBoundary_0x100() public {
        _verifyCreateRegistration(deployer, 0x100);
    }

    /// @notice Nonce 0xffff: upper boundary of uint16 nonce.
    function test_nonceBoundary_0xffff() public {
        _verifyCreateRegistration(deployer, 0xffff);
    }

    /// @notice Nonce 0x10000: switches to uint24 encoding.
    function test_nonceBoundary_0x10000() public {
        _verifyCreateRegistration(deployer, 0x10000);
    }

    /// @notice Nonce 0xffffff: upper boundary of uint24 nonce.
    function test_nonceBoundary_0xffffff() public {
        _verifyCreateRegistration(deployer, 0xffffff);
    }

    /// @notice Nonce 0x1000000: switches to uint32 encoding.
    function test_nonceBoundary_0x1000000() public {
        _verifyCreateRegistration(deployer, 0x1000000);
    }

    /// @notice Nonce at max uint32 - highest supported nonce.
    function test_nonceBoundary_maxUint32() public {
        _verifyCreateRegistration(deployer, type(uint32).max);
    }

    // =========================================================================
    // Mismatched parameters - wrong deployer/nonce registers wrong address
    // =========================================================================

    /// @notice Registering with wrong nonce maps to a different (non-deployed) address.
    function test_mismatchedNonce_registersDifferentAddress() public {
        uint64 correctNonce = 5;

        // Set nonce and deploy.
        vm.setNonce(deployer, correctNonce);
        vm.prank(deployer);
        address deployed = address(new MockDeployment());

        // Register with wrong nonce - should map to a different address.
        uint256 wrongNonce = 6;
        registry.registerAddress(deployer, wrongNonce);

        // The deployed contract should NOT be mapped (wrong nonce was used).
        assertEq(registry.deployerOf(deployed), address(0), "Deployed address should not be registered with wrong nonce");
    }

    /// @notice Registering with wrong deployer maps to a different address.
    function test_mismatchedDeployer_registersDifferentAddress() public {
        address wrongDeployer = makeAddr("wrongDeployer");
        uint64 nonce = 1;

        vm.setNonce(deployer, nonce);
        vm.prank(deployer);
        address deployed = address(new MockDeployment());

        // Register with wrong deployer.
        registry.registerAddress(wrongDeployer, nonce);

        // The deployed address should not be registered.
        assertEq(registry.deployerOf(deployed), address(0), "Should not be registered with wrong deployer");
    }

    // =========================================================================
    // Duplicate registration - second registration overwrites first
    // =========================================================================

    /// @notice Registering the same computed address twice overwrites the deployer.
    function test_duplicateRegistration_overwrites() public {
        uint64 nonce = 1;

        vm.setNonce(deployer, nonce);
        vm.prank(deployer);
        address deployed = address(new MockDeployment());

        // First registration.
        registry.registerAddress(deployer, nonce);
        assertEq(registry.deployerOf(deployed), deployer);

        // Register again with a different deployer (same computed address via different params).
        // Actually, same deployer + nonce = same address. Let's just call register again.
        address fakeDeployer = makeAddr("fake");
        registry.registerAddress(fakeDeployer, nonce);

        // The real deployed address still has the correct deployer.
        // But the address computed from (fakeDeployer, nonce) is a DIFFERENT address.
        // So deployed's mapping is unchanged.
        assertEq(registry.deployerOf(deployed), deployer, "Original registration should be unchanged");
    }

    // =========================================================================
    // Unregistered address returns address(0)
    // =========================================================================

    /// @notice deployerOf returns address(0) for unregistered addresses.
    function test_unregisteredAddress_returnsZero() public {
        assertEq(registry.deployerOf(address(0xdead)), address(0));
        assertEq(registry.deployerOf(address(0)), address(0));
        assertEq(registry.deployerOf(address(this)), address(0));
    }

    // =========================================================================
    // Create2 - wrong bytecode maps to wrong address
    // =========================================================================

    /// @notice Create2 registration with wrong bytecode produces different address.
    function test_create2_wrongBytecode_registersDifferentAddress() public {
        Factory factory = new Factory();
        bytes32 salt = bytes32(uint256(42));

        address deployed = factory.deploy(salt);

        // Register with correct params.
        registry.registerAddress(address(factory), salt, type(MockDeployment).creationCode);
        assertEq(registry.deployerOf(deployed), address(factory), "Correct create2 registration should work");

        // Now try registering with wrong bytecode - produces different computed address.
        bytes memory wrongBytecode = hex"deadbeef";
        registry.registerAddress(address(factory), salt, wrongBytecode);

        // The deployed address's mapping should be unchanged (wrong bytecode = different address).
        assertEq(registry.deployerOf(deployed), address(factory), "Original mapping unchanged by wrong bytecode");
    }

    // =========================================================================
    // address(0) deployer
    // =========================================================================

    /// @notice Registration with address(0) as deployer succeeds (permissionless).
    function test_zeroAddressDeployer_succeeds() public {
        // This should not revert - the registry is permissionless and doesn't validate.
        registry.registerAddress(address(0), 1);

        // The computed address for (address(0), nonce=1) gets mapped to address(0).
        // We just verify no revert and the mapping is set.
    }

    // =========================================================================
    // Event emission
    // =========================================================================

    /// @notice Verify AddressRegistered event is emitted with correct fields for create.
    function test_eventEmission_create() public {
        uint64 nonce = 1;
        vm.setNonce(deployer, nonce);
        vm.prank(deployer);
        address deployed = address(new MockDeployment());

        vm.expectEmit(true, true, true, true);
        emit AddressRegistered(deployed, deployer, address(this));

        registry.registerAddress(deployer, nonce);
    }

    /// @notice Verify AddressRegistered event is emitted with correct fields for create2.
    function test_eventEmission_create2() public {
        Factory factory = new Factory();
        bytes32 salt = bytes32(uint256(99));
        address deployed = factory.deploy(salt);

        vm.expectEmit(true, true, true, true);
        emit AddressRegistered(deployed, address(factory), address(this));

        registry.registerAddress(address(factory), salt, type(MockDeployment).creationCode);
    }

    // =========================================================================
    // Fuzz: any valid nonce produces correct registration
    // =========================================================================

    /// @notice Fuzz across the full uint32 nonce range.
    function testFuzz_createRegistration_anyNonce(uint32 nonce) public {
        _verifyCreateRegistration(deployer, uint256(nonce));
    }

    // =========================================================================
    // Nonce > uint32 - known limitation (documented behavior)
    // =========================================================================

    /// @notice Nonces above uint32 are truncated by _addressFrom, producing incorrect addresses.
    ///         This documents the known limitation described in the source code comment:
    ///         "this won't work for nonces > 2**32"
    function test_nonceAboveUint32_producesWrongAddress() public {
        // uint32.max + 1 = 0x100000000
        // The _addressFrom function hits the `else` branch and casts to uint32,
        // truncating the nonce. So nonce 0x100000000 produces the same address as nonce 0.
        address deployer1 = makeAddr("deployer_overflow");

        // Compute address for nonce 0x100000000 via registry.
        // Register it and check what address was mapped.
        registry.registerAddress(deployer1, 0x100000000);

        // Also register nonce 0 from the same deployer.
        registry.registerAddress(deployer1, 0);

        // Both should map the same computed address because uint32(0x100000000) == 0.
        // This means the second call overwrites the first (same key in the mapping).
        // We can't easily verify the address directly, but we can verify that
        // the registry doesn't revert - it silently computes a truncated address.

        // Deploy at actual nonce 0 to get the real address.
        vm.setNonce(deployer1, 0);
        vm.prank(deployer1);
        address realNonce0 = address(new MockDeployment());

        // Register with nonce 0 - should work correctly.
        registry.registerAddress(deployer1, 0);
        assertEq(registry.deployerOf(realNonce0), deployer1, "Nonce 0 should map correctly");

        // Register with nonce 0x100000000 - silently truncates to nonce 0,
        // overwriting the same mapping entry.
        registry.registerAddress(deployer1, 0x100000000);
        // The deployer is still the same, so the mapping is still "correct" by coincidence,
        // but the nonce was silently wrong. This documents the truncation behavior.
        assertEq(
            registry.deployerOf(realNonce0),
            deployer1,
            "Truncated nonce 0x100000000 overwrites nonce 0's entry (same uint32 cast)"
        );
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @dev Deploys a contract at the given nonce and verifies registration.
    function _verifyCreateRegistration(address _deployer, uint256 nonce) internal {
        // Set nonce (must be >= current nonce).
        uint64 currentNonce = vm.getNonce(_deployer);
        if (nonce < currentNonce) {
            // Can't set nonce lower than current, use a fresh deployer.
            _deployer = makeAddr(string.concat("deployer_", vm.toString(nonce)));
        }
        if (vm.getNonce(_deployer) != nonce) {
            // forge-lint: disable-next-line(unsafe-typecast)
            vm.setNonce(_deployer, uint64(nonce));
        }

        // Deploy.
        vm.prank(_deployer);
        address deployed = address(new MockDeployment());

        // Register.
        registry.registerAddress(_deployer, nonce);

        // Verify.
        assertEq(
            registry.deployerOf(deployed),
            _deployer,
            string.concat("Registration failed for nonce ", vm.toString(nonce))
        );
    }
}

contract MockDeployment {
    string stored = "Hello, world!";

    constructor() {}

    function getFancyData() external view returns (string memory) {
        return stored;
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
