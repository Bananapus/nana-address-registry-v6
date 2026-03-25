# Audit Instructions -- nana-address-registry-v6

You are auditing a permissionless address registry for Juicebox V6. The contract stores a mapping from deployed contract addresses to their deployers, computed deterministically from `create` or `create2` parameters. It has no owner, no access control, no constructor arguments, and no external dependencies. Read [RISKS.md](./RISKS.md) first -- it documents all known risks and trust assumptions. Then come back here.

## Compiler and Version Info

| Setting | Value |
|---------|-------|
| Solidity version | 0.8.28 |
| EVM target | cancun |
| Optimizer | enabled, 200 runs |
| via-IR | not enabled |
| Fuzz runs | 4,096 |
| Invariant runs | 1,024 (depth 100) |

Source: [`foundry.toml`](./foundry.toml)

## Previous Audit Findings

A Nemesis automated audit was conducted on 2026-03-17. Results are in [`.audit/findings/nemesis-verified.md`](./.audit/findings/nemesis-verified.md). Summary:

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| NM-001 | LOW | Deployment library project name mismatch (`"nana-address-registry"` vs `"nana-address-registry-v6"`) | Open (deployment script only, no runtime impact) |

The core contract (`JBAddressRegistry`) was verified sound -- RLP encoding is correct across all 10 nonce ranges, CREATE2 computation matches EIP-1014. No CRITICAL, HIGH, or MEDIUM findings were identified.

No prior formal audit with finding IDs from an external security firm has been conducted.

## Scope

**In scope -- all Solidity in `src/`:**
```
src/JBAddressRegistry.sol              # Registry implementation (~127 lines)
src/interfaces/IJBAddressRegistry.sol  # Interface (~27 lines)
```

**Out of scope:** Test files, deployment scripts, forge-std.

## Architecture

### JBAddressRegistry

A standalone, stateless-logic contract with a single storage mapping:

```
mapping(address addr => address deployer) public deployerOf;
```

Two public `registerAddress` overloads accept deployer parameters, compute the deterministic address, and store the mapping. No validation is performed beyond address computation and a nonce range check.

### Registration (create)

`registerAddress(address deployer, uint256 nonce)`:
1. Calls `_addressFrom(deployer, nonce)` to compute the `create` address via RLP encoding
2. Stores `deployerOf[computedAddress] = deployer`
3. Emits `AddressRegistered(computedAddress, deployer, msg.sender)`

### Registration (create2)

`registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)`:
1. Computes `address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))))`
2. Stores `deployerOf[computedAddress] = deployer`
3. Emits `AddressRegistered(computedAddress, deployer, msg.sender)`

### RLP Encoding (_addressFrom)

The internal `_addressFrom(address origin, uint256 nonce)` function implements RLP encoding of `[origin, nonce]` for `create` address computation. It handles 10 nonce ranges covering `0` through `type(uint64).max`:

| Nonce Range | RLP Prefix Byte | Nonce Length Prefix |
|-------------|----------------|---------------------|
| `0` | `0xd6` | `0x80` (empty byte) |
| `1 - 0x7f` | `0xd6` | (none, raw byte) |
| `0x80 - 0xff` | `0xd7` | `0x81` |
| `0x100 - 0xffff` | `0xd8` | `0x82` |
| `0x10000 - 0xffffff` | `0xd9` | `0x83` |
| `0x1000000 - 0xffffffff` | `0xda` | `0x84` |
| `0x100000000 - 0xffffffffff` | `0xdb` | `0x85` |
| `0x10000000000 - 0xffffffffffff` | `0xdc` | `0x86` |
| `0x1000000000000 - 0xffffffffffffff` | `0xdd` | `0x87` |
| `0x100000000000000 - 0xffffffffffffffff` | `0xde` | `0x88` |

The final address is extracted from `keccak256(rlp_data)` via inline assembly: `mstore(0, hash); addr := mload(0)`.

Nonces above `type(uint64).max` revert with `JBAddressRegistry_NonceTooLarge`.

## Priority Audit Areas

### 1. RLP Encoding Correctness (Highest Priority)

The `_addressFrom` function is the only non-trivial logic in the contract. Verify:

- **Every nonce range boundary is correct.** The if/else chain must produce correct RLP for every boundary value: `0`, `1`, `0x7f`, `0x80`, `0xff`, `0x100`, `0xffff`, `0x10000`, etc., up to `type(uint64).max`. An off-by-one at any boundary would silently produce wrong addresses.
- **RLP prefix bytes are correct.** The first byte (`0xd6`-`0xde`) encodes the total length of the list. Verify each prefix matches the actual encoded data length (20-byte address + nonce encoding + overhead).
- **Nonce encoding is correct.** For nonce `0`, the RLP encoding is `0x80` (empty byte string), not `0x00`. For nonces `1-0x7f`, the nonce IS the RLP encoding (single byte). For `0x80+`, a length prefix is prepended.
- **Assembly address extraction.** The final `mstore(0, hash); addr := mload(0)` extracts the low 160 bits of the keccak256 hash. Verify this is equivalent to `address(uint160(uint256(hash)))`.
- **Comparison with reference implementations.** Cross-check against the Ethereum Yellow Paper, OpenZeppelin's `Create2` library, and the linked StackExchange reference (https://ethereum.stackexchange.com/a/87840/68134).

### 2. create2 Address Computation

The `create2` overload uses `abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))`. Verify:
- This matches the EIP-1014 specification exactly.
- The `bytes calldata bytecode` parameter is hashed correctly (constructor arguments must be included by the caller; the contract does not append them).
- No length ambiguity in the packed encoding (each component has fixed size: 1 + 20 + 32 + 32 = 85 bytes).

### 3. Overwrite Behavior

`_registerAddress` unconditionally overwrites `deployerOf[addr]`. Verify:
- A re-registration with the same parameters produces the same result (idempotent).
- A re-registration with different parameters that happen to compute the same address (collision) would overwrite. Since address collisions require a keccak256 collision, this is cryptographically infeasible -- but confirm there is no cheaper attack vector.
- The `caller` field in the `AddressRegistered` event correctly reflects `msg.sender`, not the `deployer` parameter.

### 4. Gas and DoS

The contract has no loops, no arrays, and no unbounded storage growth beyond the mapping. Verify:
- `registerAddress` has bounded gas cost regardless of inputs.
- The `bytecode` parameter in the `create2` overload is hashed in memory. For very large bytecode, this could consume significant memory gas but cannot cause an OOG in the registry itself (the caller pays).

## Invariants to Verify

1. **Determinism**: For any `(deployer, nonce)` pair, `_addressFrom` always returns the same address, and that address matches what the EVM would produce for a `create` deployment from `deployer` at `nonce`.
2. **create2 correctness**: For any `(deployer, salt, bytecode)` triple, the computed address matches what the EVM would produce for a `create2` deployment.
3. **No side effects**: `registerAddress` only modifies `deployerOf[computedAddress]` and emits one event. No other state is touched.
4. **Nonce boundary completeness**: Every valid nonce (0 through `type(uint64).max`) produces a correct RLP encoding. No nonce in this range falls through without being encoded.

## Testing Setup

```bash
cd nana-address-registry-v6
npm install
forge build
forge test

# Run edge case tests
forge test --match-contract JBAddressRegistryEdge -vvv

# Run nonce truncation regression test
forge test --match-path test/regression/NonceTruncation.t.sol -vvv

# Run fork tests
forge test --match-contract Fork -vvv

# Write a PoC
forge test --match-path test/audit/ExploitPoC.t.sol -vvv
```

Go break it.
