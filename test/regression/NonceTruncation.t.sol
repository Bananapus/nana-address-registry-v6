// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

/// @title NonceTruncation
/// @notice _addressFrom originally only handled nonces up to uint32 max,
///         silently truncating larger values. The fix extends RLP encoding to uint64 max and adds
///         an explicit revert for nonces beyond that range.
contract NonceTruncation is Test {
    JBAddressRegistry registry;
    address deployer = makeAddr("deployer");

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    /// @notice Nonce exactly at uint32 max should succeed.
    function test_nonceAtUint32Max_succeeds() public {
        registry.registerAddress(deployer, type(uint32).max);
    }

    /// @notice Nonce one above uint32 max should now succeed (uint64 support added).
    function test_nonceAboveUint32Max_succeeds() public {
        uint256 nonce = uint256(type(uint32).max) + 1;
        // Should not revert -- the fix extended support to uint64.
        registry.registerAddress(deployer, nonce);
    }

    /// @notice Nonce at uint64 max should succeed (upper boundary of support).
    function test_nonceAtUint64Max_succeeds() public {
        registry.registerAddress(deployer, type(uint64).max);
    }

    /// @notice Nonce one above uint64 max should revert with NonceTooLarge.
    function test_nonceAboveUint64Max_reverts() public {
        uint256 tooLargeNonce = uint256(type(uint64).max) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, tooLargeNonce)
        );
        registry.registerAddress(deployer, tooLargeNonce);
    }

    /// @notice A nonce at uint256 max should revert with NonceTooLarge.
    function test_nonceUint256Max_reverts() public {
        uint256 maxNonce = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, maxNonce));
        registry.registerAddress(deployer, maxNonce);
    }

    /// @notice Fuzz: any nonce above uint64 max should revert.
    function testFuzz_nonceAboveUint64Max_reverts(uint256 nonce) public {
        vm.assume(nonce > type(uint64).max);

        vm.expectRevert(abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, nonce));
        registry.registerAddress(deployer, nonce);
    }

    /// @notice Fuzz: any nonce within uint64 range should succeed (no revert).
    function testFuzz_nonceWithinUint64Range_succeeds(uint64 nonce) public {
        registry.registerAddress(deployer, uint256(nonce));
    }
}
