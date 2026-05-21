// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

/// @notice Small Halmos entrypoints for the registry's deterministic CREATE address helper.
/// @dev The checks pin every RLP nonce-width boundary. Registration itself is covered by Foundry tests because it
/// depends on runtime code existing at the computed address.
contract JBAddressRegistryHalmos is JBAddressRegistry {
    /// @notice Exposes the inherited internal helper so the overflow check can be caught through an external call.
    /// @param origin The CREATE deployer.
    /// @param nonce The CREATE nonce.
    /// @return addr The predicted deployment address.
    function exposedAddressFrom(address origin, uint256 nonce) external pure returns (address addr) {
        return _addressFrom({origin: origin, nonce: nonce});
    }

    /// @notice Proves the nonce-0 RLP sentinel branch.
    /// @param origin The symbolic CREATE deployer.
    function check_nonceZeroUsesEmptyStringSentinel(address origin) public pure {
        assert(
            _addressFrom({origin: origin, nonce: 0})
                == _reference({data: abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, bytes1(0x80))})
        );
    }

    /// @notice Proves one-byte nonces up to 0x7f are encoded directly, without the 0x81 payload-length prefix.
    /// @param origin The symbolic CREATE deployer.
    /// @param nonce The symbolic nonce constrained to the direct one-byte RLP range.
    function check_directOneByteNonce(address origin, uint8 nonce) public pure {
        if (nonce == 0 || nonce > 0x7f) return;

        assert(
            _addressFrom({origin: origin, nonce: nonce})
                == _reference({data: abi.encodePacked(bytes1(0xd6), bytes1(0x94), origin, nonce)})
        );
    }

    /// @notice Proves one-byte payload nonces from 0x80 through 0xff use the 0x81 length prefix.
    /// @param origin The symbolic CREATE deployer.
    /// @param nonce The symbolic nonce constrained to the one-byte payload RLP range.
    function check_prefixedOneByteNonce(address origin, uint8 nonce) public pure {
        if (nonce <= 0x7f) return;

        assert(
            _addressFrom({origin: origin, nonce: nonce})
                == _reference({data: abi.encodePacked(bytes1(0xd7), bytes1(0x94), origin, bytes1(0x81), nonce)})
        );
    }

    /// @notice Proves every wider RLP payload branch at both its lower and upper boundary.
    /// @param origin The symbolic CREATE deployer.
    function check_wideNonceBoundaryTable(address origin) public pure {
        _assertCreateAddress({origin: origin, nonce: 0x0100, prefix: 0xd8, payloadLengthPrefix: 0x82});
        _assertCreateAddress({origin: origin, nonce: 0xffff, prefix: 0xd8, payloadLengthPrefix: 0x82});

        _assertCreateAddress({origin: origin, nonce: 0x010000, prefix: 0xd9, payloadLengthPrefix: 0x83});
        _assertCreateAddress({origin: origin, nonce: 0xffffff, prefix: 0xd9, payloadLengthPrefix: 0x83});

        _assertCreateAddress({origin: origin, nonce: 0x01000000, prefix: 0xda, payloadLengthPrefix: 0x84});
        _assertCreateAddress({origin: origin, nonce: 0xffffffff, prefix: 0xda, payloadLengthPrefix: 0x84});

        _assertCreateAddress({origin: origin, nonce: 0x0100000000, prefix: 0xdb, payloadLengthPrefix: 0x85});
        _assertCreateAddress({origin: origin, nonce: 0xffffffffff, prefix: 0xdb, payloadLengthPrefix: 0x85});

        _assertCreateAddress({origin: origin, nonce: 0x010000000000, prefix: 0xdc, payloadLengthPrefix: 0x86});
        _assertCreateAddress({origin: origin, nonce: 0xffffffffffff, prefix: 0xdc, payloadLengthPrefix: 0x86});

        _assertCreateAddress({origin: origin, nonce: 0x01000000000000, prefix: 0xdd, payloadLengthPrefix: 0x87});
        _assertCreateAddress({origin: origin, nonce: 0xffffffffffffff, prefix: 0xdd, payloadLengthPrefix: 0x87});

        _assertCreateAddress({origin: origin, nonce: 0x0100000000000000, prefix: 0xde, payloadLengthPrefix: 0x88});
        _assertCreateAddress({
            origin: origin, nonce: uint256(type(uint64).max), prefix: 0xde, payloadLengthPrefix: 0x88
        });
    }

    /// @notice Proves the registry rejects CREATE nonces outside its explicit uint64 support bound.
    /// @param origin The symbolic CREATE deployer.
    function check_nonceAboveUint64Reverts(address origin) public view {
        try this.exposedAddressFrom({origin: origin, nonce: uint256(type(uint64).max) + 1}) returns (address) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    /// @notice Asserts one fixed nonce boundary against a readable RLP reference encoding.
    /// @param origin The symbolic CREATE deployer.
    /// @param nonce The nonce boundary being checked.
    /// @param prefix The RLP list prefix for the encoded `[origin, nonce]` tuple.
    /// @param payloadLengthPrefix The RLP integer payload-length prefix for `nonce`.
    function _assertCreateAddress(
        address origin,
        uint256 nonce,
        uint8 prefix,
        uint8 payloadLengthPrefix
    )
        internal
        pure
    {
        assert(
            _addressFrom({origin: origin, nonce: nonce})
                == _reference({
                    data: abi.encodePacked(
                        bytes1(prefix),
                        bytes1(0x94),
                        origin,
                        bytes1(payloadLengthPrefix),
                        _minimalBigEndian({value: nonce})
                    )
                })
        );
    }

    /// @notice Returns the right-trimmed big-endian nonce bytes used by RLP integer encoding.
    /// @param value The nonce to encode.
    /// @return encoded The minimal big-endian byte string.
    function _minimalBigEndian(uint256 value) internal pure returns (bytes memory encoded) {
        uint256 bytesNeeded;
        uint256 remaining = value;
        while (remaining != 0) {
            ++bytesNeeded;
            remaining >>= 8;
        }

        encoded = new bytes(bytesNeeded);
        for (uint256 i; i < bytesNeeded;) {
            // The truncation is intentional: after shifting the target byte into the low 8 bits, RLP needs exactly
            // that single byte in big-endian order.
            // forge-lint: disable-next-line(unsafe-typecast)
            encoded[bytesNeeded - 1 - i] = bytes1(uint8(value >> (i * 8)));

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Reference implementation for Ethereum's CREATE address derivation once RLP bytes are known.
    /// @param data The RLP encoded `[origin, nonce]`.
    /// @return addr The expected CREATE deployment address.
    function _reference(bytes memory data) internal pure returns (address addr) {
        addr = address(uint160(uint256(keccak256(data))));
    }
}
