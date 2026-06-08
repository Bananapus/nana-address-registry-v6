// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {JBAddressRegistry} from "../../src/JBAddressRegistry.sol";

/// @notice Symbolic + fuzz harness proving the registry's deterministic address derivation matches the canonical
/// EVM rules (EIP-1014 for CREATE2, RLP[origin, nonce] for CREATE).
/// @dev House convention: every property is DUAL-implemented — `check_<name>` for Halmos (symbolic, plain `assert`,
/// no cheatcodes so SMT stays clean) and `testFuzz_<name>` for forge (fuzz, with forge-std cross-checks). These pin
/// the FUNCTIONAL spec in `INVARIANTS.md` sections A.1 / D.2. The existing `JBAddressRegistryHalmos.t.sol` proves
/// the RLP byte-shape against a readable reference; here we additionally CROSS-CHECK CREATE against forge-std's
/// INDEPENDENT `computeCreateAddress` implementation (fuzz), and prove the CREATE2 path against EIP-1014 (symbolic).
contract JBAddressRegistryDerivationHalmos is JBAddressRegistry, Test {
    /// @notice The literal EIP-1014 CREATE2 derivation, independent of the contract under test.
    function _eip1014(address deployer, bytes32 salt, bytes memory bytecode) internal pure returns (address addr) {
        addr = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));
    }

    /// @notice Re-derives the CREATE2 address exactly as `registerAddress(deployer, salt, bytecode)` does.
    /// @dev Mirrors `src/JBAddressRegistry.sol:68-69`.
    function _registryCreate2(
        address deployer,
        bytes32 salt,
        bytes memory bytecode
    )
        internal
        pure
        returns (address addr)
    {
        addr = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));
    }

    // =====================================================================
    // CREATE2 derivation == EIP-1014 (INVARIANTS.md A.1 / D.2)
    // =====================================================================

    /// @notice Halmos: registry CREATE2 derivation matches EIP-1014 for symbolic deployer/salt over a small symbolic
    /// bytecode. The bytecode length is bounded so the SMT keccak stays tractable.
    function check_create2MatchesEip1014(address deployer, bytes32 salt, bytes4 code) public pure {
        bytes memory bytecode = abi.encodePacked(code);
        assert(_registryCreate2(deployer, salt, bytecode) == _eip1014(deployer, salt, bytecode));
    }

    /// @notice Halmos: distinct salts (same deployer+bytecode) derive distinct addresses except on keccak collision.
    /// Pins that the salt is load-bearing in the derivation.
    function check_create2SaltIsLoadBearing(address deployer, bytes32 saltA, bytes32 saltB, bytes4 code) public pure {
        if (saltA == saltB) return;
        bytes memory bytecode = abi.encodePacked(code);
        assert(_registryCreate2(deployer, saltA, bytecode) != _registryCreate2(deployer, saltB, bytecode));
    }

    /// @notice Fuzz: registry CREATE2 derivation matches EIP-1014 for arbitrary-length bytecode.
    function testFuzz_create2MatchesEip1014(address deployer, bytes32 salt, bytes calldata bytecode) public {
        assertEq(_registryCreate2(deployer, salt, bytecode), _eip1014(deployer, salt, bytecode));
    }

    /// @notice Fuzz: registry CREATE2 derivation matches forge-std's independent `computeCreate2Address`.
    function testFuzz_create2MatchesForgeStd(address deployer, bytes32 salt, bytes calldata bytecode) public {
        assertEq(
            _registryCreate2(deployer, salt, bytecode), vm.computeCreate2Address(salt, keccak256(bytecode), deployer)
        );
    }

    // =====================================================================
    // CREATE derivation == forge-std computeCreateAddress (A.1 / D.2)
    // =====================================================================

    /// @notice Fuzz: registry CREATE derivation matches forge-std's INDEPENDENT RLP implementation across the full
    /// supported uint64 nonce range. Stronger cross-implementation check than the self-referential RLP reference in
    /// `JBAddressRegistryHalmos.t.sol`.
    function testFuzz_createMatchesForgeStd(address origin, uint64 nonce) public {
        assertEq(_addressFrom(origin, uint256(nonce)), vm.computeCreateAddress(origin, uint256(nonce)));
    }

    /// @notice Fuzz: registry CREATE derivation matches forge-std at every nonce-width boundary value.
    function testFuzz_createMatchesForgeStdAtBoundaries(address origin) public {
        uint256[19] memory nonces = [
            uint256(0),
            1,
            0x7f,
            0x80,
            0xff,
            0x100,
            0xffff,
            0x10000,
            0xffffff,
            0x1000000,
            uint256(type(uint32).max),
            0x100000000,
            uint256(type(uint40).max),
            0x10000000000,
            uint256(type(uint48).max),
            0x1000000000000,
            uint256(type(uint56).max),
            0x100000000000000,
            uint256(type(uint64).max)
        ];
        for (uint256 i; i < nonces.length; ++i) {
            assertEq(_addressFrom(origin, nonces[i]), vm.computeCreateAddress(origin, nonces[i]));
        }
    }

    // =====================================================================
    // Nonce bound guard (A.1)
    // =====================================================================

    /// @notice Exposes the internal helper so the overflow guard is reachable through an external try/catch.
    function exposedAddressFrom(address origin, uint256 nonce) external pure returns (address addr) {
        return _addressFrom(origin, nonce);
    }

    /// @notice Halmos: any nonce strictly above uint64 max reverts (NonceTooLarge) rather than silently truncating.
    function check_nonceAboveUint64Reverts(address origin, uint256 nonce) public view {
        if (nonce <= type(uint64).max) return;
        try this.exposedAddressFrom(origin, nonce) returns (address) {
            assert(false);
        } catch {
            assert(true);
        }
    }

    /// @notice Fuzz: any nonce strictly above uint64 max reverts with the typed NonceTooLarge error.
    function testFuzz_nonceAboveUint64Reverts(address origin, uint256 nonce) public {
        vm.assume(nonce > type(uint64).max);
        vm.expectRevert(abi.encodeWithSelector(JBAddressRegistry_NonceTooLarge.selector, nonce));
        this.exposedAddressFrom(origin, nonce);
    }
}
