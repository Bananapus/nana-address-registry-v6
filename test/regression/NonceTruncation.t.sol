// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

/// @title NonceTruncation
/// @notice _addressFrom originally only handled nonces up to uint32 max,
///         silently truncating larger values. The fix extends RLP encoding to uint64 max and adds
///         an explicit revert for nonces beyond that range.
contract NonceTruncation is Test {
    JBAddressRegistry registry;
    address deployer = makeAddr("deployer");
    bytes constant DUMMY_CODE = hex"00";

    function setUp() public {
        registry = new JBAddressRegistry();
    }

    /// @notice Nonce exactly at uint32 max should succeed.
    function test_nonceAtUint32Max_succeeds() public {
        vm.etch(vm.computeCreateAddress(deployer, type(uint32).max), DUMMY_CODE);
        registry.registerAddress(deployer, type(uint32).max);
    }

    /// @notice Nonce one above uint32 max should now succeed (uint64 support added).
    function test_nonceAboveUint32Max_succeeds() public {
        uint256 nonce = uint256(type(uint32).max) + 1;
        vm.etch(_predicted(deployer, nonce), DUMMY_CODE);
        registry.registerAddress(deployer, nonce);
    }

    /// @notice Nonce at uint64 max should succeed (upper boundary of support).
    function test_nonceAtUint64Max_succeeds() public {
        vm.etch(_predicted(deployer, type(uint64).max), DUMMY_CODE);
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
        vm.etch(_predicted(deployer, uint256(nonce)), DUMMY_CODE);
        registry.registerAddress(deployer, uint256(nonce));
    }

    function _predicted(address origin, uint256 nonce) internal pure returns (address addr) {
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
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xdb), bytes1(0x94), origin, bytes1(0x85), uint40(nonce));
        } else if (nonce <= 0xffffffffffff) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xdc), bytes1(0x94), origin, bytes1(0x86), uint48(nonce));
        } else if (nonce <= 0xffffffffffffff) {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xdd), bytes1(0x94), origin, bytes1(0x87), uint56(nonce));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            data = abi.encodePacked(bytes1(0xde), bytes1(0x94), origin, bytes1(0x88), uint64(nonce));
        }
        bytes32 hash = keccak256(data);
        assembly {
            mstore(0, hash)
            addr := mload(0)
        }
    }
}
