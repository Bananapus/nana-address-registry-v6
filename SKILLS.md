# Juicebox Address Registry

## Purpose

Allows anyone to register the deployer of a contract so that frontend clients can verify trust -- primarily for Juicebox pay/cash-out hooks, but works for any contract deployed via `create` or `create2`. The contract has no constructor arguments, no access control, no owner, and no external dependencies. Security relies entirely on the mathematical properties of deterministic address computation.

## Deployed Address

Same address on all networks (deterministic `create2` via Sphinx with salt `_JBAddressRegistryV6_`):

```
0x2d9b78cb37ca724cfb9b32cd8e9a5dc1c88bc7bb
```

Deployed on: Ethereum, Optimism, Arbitrum, Base, and their Sepolia testnets.

## Contracts

| Contract | Role |
|----------|------|
| `JBAddressRegistry` | Standalone registry. Stores `mapping(address => address) deployerOf`. Computes addresses deterministically from deployer + deployment params, then writes the mapping. |

## Key Functions

| Function | Contract | What it does |
|----------|----------|--------------|
| `registerAddress(address deployer, uint256 nonce)` | `JBAddressRegistry` | Registers a contract deployed via `create`. Computes address from deployer + nonce using RLP encoding (`_addressFrom`). Stores `deployerOf[computedAddress] = deployer`. Emits `AddressRegistered`. |
| `registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)` | `JBAddressRegistry` | Registers a contract deployed via `create2`. Computes `address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))))`. Stores `deployerOf[computedAddress] = deployer`. Emits `AddressRegistered`. |
| `deployerOf(address addr)` | `JBAddressRegistry` | Returns the registered deployer of `addr`. Returns `address(0)` if not registered. This is a public mapping getter. |

## Events

| Event | Fields | Emitted By |
|-------|--------|------------|
| `AddressRegistered(address indexed addr, address indexed deployer, address caller)` | `addr`: the computed contract address. `deployer`: the deployer stored in the mapping. `caller`: `msg.sender` who called `registerAddress` (may differ from deployer). | Both `registerAddress` overloads, via internal `_registerAddress`. |

## Internal Functions

| Function | What it does |
|----------|--------------|
| `_addressFrom(address origin, uint256 nonce) returns (address)` | Computes `create` address using RLP encoding. Handles 10 nonce ranges: `0`, `1-0x7f`, `0x80-0xff`, `0x100-0xffff`, `0x10000-0xffffff`, `0x1000000-0xffffffff`, `0x100000000-0xffffffffff`, `0x10000000000-0xffffffffffff`, `0x1000000000000-0xffffffffffffff`, `0x100000000000000-0xffffffffffffffff`. Reverts with `JBAddressRegistry_NonceTooLarge` for nonces above `uint64` max. Uses `keccak256` of the RLP-encoded `[origin, nonce]` and extracts the low 160 bits via assembly. |
| `_registerAddress(address addr, address deployer)` | Reverts with `JBAddressRegistry_ZeroDeployer` if `deployer == address(0)`. Reverts with `JBAddressRegistry_AlreadyRegistered` if `deployerOf[addr] != address(0)`. Otherwise writes `deployerOf[addr] = deployer` and emits `AddressRegistered`. Shared by both public `registerAddress` overloads. |

## Errors

| Error | Defined In | Trigger Condition |
|-------|-----------|-------------------|
| `JBAddressRegistry_NonceTooLarge(uint256 nonce)` | `JBAddressRegistry` | `registerAddress(deployer, nonce)` is called with a `nonce` greater than `type(uint64).max` (18,446,744,073,709,551,615). Reverts inside `_addressFrom` before any state change. In practice unreachable since no EOA or contract can reach this nonce. |
| `JBAddressRegistry_AlreadyRegistered(address addr)` | `JBAddressRegistry` | Either `registerAddress` overload is called with parameters that compute to an address already present in `deployerOf`. Reverts inside `_registerAddress` before any state change. |
| `JBAddressRegistry_ZeroDeployer()` | `JBAddressRegistry` | Either `registerAddress` overload is called with `deployer == address(0)`. Reverts inside `_registerAddress` before any state change. |

Both `registerAddress` overloads can revert with `JBAddressRegistry_ZeroDeployer` (if `deployer == address(0)`) and `JBAddressRegistry_AlreadyRegistered` (if the computed address was previously registered). The `create` overload can additionally revert with `JBAddressRegistry_NonceTooLarge`. Invalid `create2` parameters (wrong salt or bytecode) do not revert — they silently compute the wrong address.

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| None | -- | This contract is fully standalone with no external dependencies. |

The npm package name is `@bananapus/address-registry-v6`. Import the interface with:

```solidity
import {IJBAddressRegistry} from "@bananapus/address-registry-v6/src/interfaces/IJBAddressRegistry.sol";
```

## Key Types

| Type | Description |
|------|-------------|
| `IJBAddressRegistry` | Interface declaring `deployerOf`, both `registerAddress` overloads, and the `AddressRegistered` event. Pragma `^0.8.0`. |
| `AddressRegistryDeployment` | Struct in `script/helpers/AddressRegistryDeploymentLib.sol` containing `IJBAddressRegistry registry`. Used by deploy scripts to pass around the deployed instance. |

## Storage Layout

Single slot category:

```
mapping(address addr => address deployer) public deployerOf;
```

No arrays, no structs, no linked lists. One mapping, that is all.

## Deployment Details

- Deploy script: `script/Deploy.s.sol`
- Salt: `bytes32("_JBAddressRegistryV6_")`
- Deployer proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C` (Arachnid deterministic deployment proxy)
- The script checks if code already exists at the computed address and skips deployment if so
- `AddressRegistryDeploymentLib` (in `script/helpers/`) resolves deployed addresses from Sphinx JSON artifacts by chain ID

## Gotchas

- **Nonce limit**: `_addressFrom` supports nonces up to `uint64` max (18,446,744,073,709,551,615). Nonces above this revert with `JBAddressRegistry_NonceTooLarge`. In practice this limit is unreachable.
- **No overwrite — duplicate reverts**: Calling `registerAddress` with parameters that compute to an already-registered address reverts with `JBAddressRegistry_AlreadyRegistered`. Only the first registration is accepted.
- **Permissionless**: Anyone can call `registerAddress`, not just the deployer. `msg.sender` is recorded in the event as `caller` but is NOT stored in the mapping. Only the computed deployer is stored.
- **No validation**: The registry does not check that `addr` has code deployed, or that the deployer is a real deployer. It purely does math and stores the result. If you pass wrong parameters, it silently registers a mapping for the wrong address. Frontends MUST verify `addr.code.length > 0` (or `extcodesize(addr) > 0` in assembly) before trusting a registry entry.
- **`deployerOf` returns `address(0)` for unregistered addresses**: This is the default mapping value, not a sentinel. Since `JBAddressRegistry_ZeroDeployer` prevents registering `address(0)` as a deployer, `deployerOf[addr] == address(0)` reliably means "not registered".
- **`create2` bytecode must include constructor args**: When registering a `create2` deployment, the `bytecode` parameter must be the full creation bytecode including ABI-encoded constructor arguments: `abi.encodePacked(type(Contract).creationCode, abi.encode(arg1, arg2, ...))`. Omitting constructor args will compute the wrong address.
- **Contract nonces start at 1**: When using the `create` overload to register a contract deployed by another contract, remember that contract nonces start at 1 (not 0 like EOAs). The first contract deployed by a factory is at nonce 1.
- **Solidity version**: The implementation uses `pragma solidity 0.8.28`. The interface uses `pragma solidity ^0.8.0` (flexible) so it can be imported by any 0.8.x consumer.

## Example: Register a `create` Deployment

```solidity
import {IJBAddressRegistry} from "@bananapus/address-registry-v6/src/interfaces/IJBAddressRegistry.sol";

// After deploying a hook from a factory contract:
address hook = address(new MyPayHook(projectId));
// Factory's nonce was N when it deployed the hook.
// If this is the factory's first deployment, nonce = 1.
registry.registerAddress(address(this), 1);
```

## Example: Register a `create2` Deployment

```solidity
import {IJBAddressRegistry} from "@bananapus/address-registry-v6/src/interfaces/IJBAddressRegistry.sol";

bytes32 salt = keccak256(abi.encode(projectId));
address hook = address(new MyPayHook{salt: salt}(projectId));

// Bytecode must include constructor arguments.
bytes memory bytecode = abi.encodePacked(
    type(MyPayHook).creationCode,
    abi.encode(projectId)
);
registry.registerAddress(address(this), salt, bytecode);
```

## Example: Frontend Lookup

```solidity
address deployer = registry.deployerOf(hookAddress);
if (deployer == address(0)) {
    // Not registered -- unknown deployer.
} else if (deployer == TRUSTED_DEPLOYER) {
    // Deployed by a known, trusted factory.
} else {
    // Registered but deployer is not in the trusted set.
}
```

## RLP Encoding Reference (for `create` address computation)

The `_addressFrom` function implements RLP encoding of `[deployer, nonce]` to match how the EVM computes `create` addresses. The encoding varies by nonce size:

| Nonce Range | RLP Prefix | Nonce Encoding |
|-------------|-----------|----------------|
| `0` | `0xd6 0x94` | `0x80` (RLP empty byte) |
| `1 - 0x7f` | `0xd6 0x94` | `uint8(nonce)` |
| `0x80 - 0xff` | `0xd7 0x94` | `0x81` + `uint8(nonce)` |
| `0x100 - 0xffff` | `0xd8 0x94` | `0x82` + `uint16(nonce)` |
| `0x10000 - 0xffffff` | `0xd9 0x94` | `0x83` + `uint24(nonce)` |
| `0x1000000 - 0xffffffff` | `0xda 0x94` | `0x84` + `uint32(nonce)` |
| `0x100000000 - 0xffffffffff` | `0xdb 0x94` | `0x85` + `uint40(nonce)` |
| `0x10000000000 - 0xffffffffffff` | `0xdc 0x94` | `0x86` + `uint48(nonce)` |
| `0x1000000000000 - 0xffffffffffffff` | `0xdd 0x94` | `0x87` + `uint56(nonce)` |
| `0x100000000000000 - 0xffffffffffffffff` | `0xde 0x94` | `0x88` + `uint64(nonce)` |

The final address is `keccak256(rlp_encoded_data)` with the low 160 bits extracted.
