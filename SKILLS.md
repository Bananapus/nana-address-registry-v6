# nana-address-registry-v6

## Purpose

Allows anyone to register the deployer of a contract so that frontend clients can verify trust -- primarily for Juicebox pay/cash-out hooks, but works for any contract deployed via `create` or `create2`.

## Contracts

| Contract | Role |
|----------|------|
| `JBAddressRegistry` | Standalone registry with no constructor arguments, no access control, and no external dependencies. |

## Key Functions

| Function | Contract | What it does |
|----------|----------|--------------|
| `registerAddress(address deployer, uint256 nonce)` | `JBAddressRegistry` | Registers a contract deployed via `create`. Computes address from deployer+nonce using RLP encoding. |
| `registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)` | `JBAddressRegistry` | Registers a contract deployed via `create2`. Computes `keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))`. |
| `deployerOf(address)` | `JBAddressRegistry` | Returns the registered deployer of a given address. Returns `address(0)` if not registered. |

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| None | -- | This contract is fully standalone with no external dependencies. |

## Key Types

| Struct/Enum | Key Fields | Used In |
|-------------|------------|---------|
| N/A | -- | No custom types. Uses a plain `mapping(address => address)` for storage. |

## Gotchas

- The `_addressFrom` function for `create` addresses only supports nonces up to `2^32`. Higher nonces produce incorrect addresses.
- No overwrite protection: calling `registerAddress` with different parameters that compute to the same address will overwrite the deployer. This is safe because only the correct deployer+parameters can produce a given address.
- Registration is permissionless -- anyone can call `registerAddress`, not just the deployer. Security relies on deterministic address computation, not access control.

## Example Integration

```solidity
import {IJBAddressRegistry} from "@bananapus/address-registry-v6/src/interfaces/IJBAddressRegistry.sol";

// After deploying a hook
address hook = new MyPayHook();
registry.registerAddress(address(this), deployerNonce);

// Frontend can verify
address deployer = registry.deployerOf(address(hook));
bool trusted = deployer == KNOWN_DEPLOYER;
```
