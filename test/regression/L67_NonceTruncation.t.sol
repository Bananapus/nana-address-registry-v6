// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

/// @title L67_NonceTruncation
/// @notice Regression test for L-67: _addressFrom silently truncated nonces > uint32 max,
///         potentially computing incorrect CREATE addresses. The fix adds an explicit revert.
contract L67_NonceTruncation is Test {
    JBAddressRegistry registry;
    address deployer = makeAddr("deployer");

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    /// @notice Nonce exactly at uint32 max should succeed.
    function test_nonceAtUint32Max_succeeds() public {
        // Should not revert - uint32 max is the highest supported nonce.
        registry.registerAddress(deployer, type(uint32).max);
    }

    /// @notice Nonce one above uint32 max should revert with NonceTooLarge.
    function test_nonceAboveUint32Max_reverts() public {
        uint256 tooLargeNonce = uint256(type(uint32).max) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, tooLargeNonce)
        );
        registry.registerAddress(deployer, tooLargeNonce);
    }

    /// @notice A very large nonce (uint64 max) should revert with NonceTooLarge.
    function test_nonceUint64Max_reverts() public {
        uint256 largeNonce = type(uint64).max;

        vm.expectRevert(abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, largeNonce));
        registry.registerAddress(deployer, largeNonce);
    }

    /// @notice A nonce at uint256 max should revert with NonceTooLarge.
    function test_nonceUint256Max_reverts() public {
        uint256 maxNonce = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, maxNonce));
        registry.registerAddress(deployer, maxNonce);
    }

    /// @notice Fuzz: any nonce above uint32 max should revert.
    function testFuzz_nonceAboveUint32Max_reverts(uint256 nonce) public {
        vm.assume(nonce > type(uint32).max);

        vm.expectRevert(abi.encodeWithSelector(JBAddressRegistry.JBAddressRegistry_NonceTooLarge.selector, nonce));
        registry.registerAddress(deployer, nonce);
    }

    /// @notice Fuzz: any nonce within uint32 range should succeed (no revert).
    function testFuzz_nonceWithinUint32Range_succeeds(uint32 nonce) public {
        // Should not revert for any valid uint32 nonce.
        registry.registerAddress(deployer, uint256(nonce));
    }
}
