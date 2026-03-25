# nana-address-registry-v6 Changelog (v5 → v6)

This document describes all changes between `nana-address-registry` (v5) and `nana-address-registry-v6` (v6).

## Summary

- **Nonce range extended from `uint32` to `uint64`**: Fixes silent address miscalculation for large nonces — previously truncated without error, now correctly RLP-encodes up to `uint64` and reverts above.
- **New `NonceTooLarge` error**: Explicit revert replaces silent truncation for nonces exceeding `uint64.max`.
- **No ABI-breaking changes**: Interface and function signatures are identical — only the internal nonce encoding logic changed.

---

## 1. Breaking Changes

- **Solidity version bump**: `0.8.23` → `^0.8.26`. Contracts compiled against v5 ABIs will still be compatible (no ABI-level breaking changes), but the compiler version requirement has changed.
- **Nonce range extended from `uint32` to `uint64`**: In v5, the `_addressFrom` function silently produced incorrect addresses for nonces at or above `2^32`. In v6, nonces up to `uint64.max` are correctly RLP-encoded, and nonces above `uint64.max` revert with `JBAddressRegistry_NonceTooLarge`. Any off-chain tooling that assumed the `uint32` ceiling must be updated.

## 2. New Features

- **Extended nonce support (uint40 through uint64)**: Four new RLP encoding branches handle nonces in the ranges `uint40`, `uint48`, `uint56`, and `uint64`, covering any realistic Ethereum account nonce.

## 3. Event Changes

None. The `AddressRegistered` event signature is identical between v5 and v6:

```solidity
event AddressRegistered(address indexed addr, address indexed deployer, address caller);
```

## 4. Error Changes

| Error | v5 | v6 |
|---|---|---|
| `JBAddressRegistry_NonceTooLarge(uint256 nonce)` | Does not exist | **Added** — reverts when `nonce > type(uint64).max` |

In v5, passing a nonce larger than `uint32` fell through to the `else` branch, which cast the nonce to `uint32`, silently truncating it and producing an incorrect address. v6 replaces this silent truncation with an explicit revert.

## 5. Implementation Changes (Non-Interface)

### `_addressFrom` — RLP nonce encoding

| Aspect | v5 | v6 |
|---|---|---|
| Maximum supported nonce | `uint32` (implicit, no guard) | `uint64` (explicit revert above) |
| Nonce > `uint32` behavior | Silent truncation to `uint32` — incorrect address computed | Correctly encodes `uint40`–`uint64`; reverts above `uint64` |
| RLP branches | 6 (`0x00`, `≤0x7f`, `≤0xff`, `≤0xffff`, `≤0xffffff`, `else→uint32`) | 10 (`0x00`, `≤0x7f`, `≤0xff`, `≤0xffff`, `≤0xffffff`, `≤0xffffffff`, `≤0xffffffffff`, `≤0xffffffffffff`, `≤0xffffffffffffff`, `else→uint64`) |
| Lint annotations | None | `forge-lint: disable-next-line(unsafe-typecast)` on each narrowing cast; `forge-lint: disable-next-line(asm-keccak256)` on inline assembly `keccak256` |

### Internal function call style

All internal function calls now use **named arguments** for clarity:

```solidity
// v5
address hook = _addressFrom(deployer, nonce);
_registerAddress(hook, deployer);

// v6
address hook = _addressFrom({origin: deployer, nonce: nonce});
_registerAddress({addr: hook, deployer: deployer});
```

### Section header naming

| v5 | v6 |
|---|---|
| `// ---------------------- internal transactions ---------------------- //` | `// -------------------------- internal views ------------------------- //` (for `_addressFrom`) |
| (none) | `// ------------------------ internal functions ----------------------- //` (new section for `_registerAddress`) |
| (none) | `// --------------------------- custom errors ------------------------- //` (new section) |

### NatDoc comment improvements

- **Contract-level**: Fixed typo `reponsible` → `responsible`; reformatted line wrapping.
- **`_addressFrom`**: Replaced informal note (`"this won't work for nonces > 2**32. If you reach that nonce please: 1) ping us, because wow 2) use another deployer"`) with a precise description (`"RLP encoding of [origin, nonce]. Supports nonces up to uint64 max"`). Attribution changed from `"Taken from"` to `"Adapted from"`.

### Interface NatDoc

The v6 interface (`IJBAddressRegistry`) adds full NatDoc documentation that was absent in v5:

- `@notice` on the interface itself.
- `@notice`, `@param`, and `@return` tags on `AddressRegistered`, `deployerOf`, and both `registerAddress` overloads.

No function signatures, parameter types, or return types changed.

## 6. Migration Table

| v5 | v6 | Action Required |
|---|---|---|
| `IJBAddressRegistry` | `IJBAddressRegistry` | **None** — ABI-identical. Update import path only. |
| `JBAddressRegistry` | `JBAddressRegistry` | **None** — ABI-compatible. Deploy new instance compiled with Solidity ^0.8.26. |
| `registerAddress(address, uint256)` | `registerAddress(address, uint256)` | **None** — signature unchanged. Nonces > `uint32` now work correctly; nonces > `uint64` now revert instead of silently producing wrong addresses. |
| `registerAddress(address, bytes32, bytes)` | `registerAddress(address, bytes32, bytes)` | **None** — signature unchanged. |
| `deployerOf(address)` | `deployerOf(address)` | **None** — signature unchanged. |
| (no error) | `JBAddressRegistry_NonceTooLarge(uint256)` | **New** — callers passing nonces > `uint64.max` must handle this revert. |
