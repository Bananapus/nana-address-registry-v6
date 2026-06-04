# V5 to V6 Changelog

## Scope

This is a V5-to-V6 migration changelog, not a package release log or commit history. It compares `nana-address-registry-v5` in `../../v5/evm` with the current `nana-address-registry-v6` repo.

## Current V6 Surface

- `JBAddressRegistry`
- `IJBAddressRegistry`

## Summary

- The public interface shape is intentionally close to V5: callers still register CREATE and CREATE2 addresses and read `deployerOf(...)`.
- V6 hardens CREATE address derivation and validation. CREATE nonce handling now rejects nonces that cannot be encoded in the supported form, and registration rejects zero deployers and addresses with no deployed code.
- The event name stays the same, but custom errors make failure modes more explicit than in V5.

## ABI, Event, and Error Changes

- Stable function surface:
  - `deployerOf(address)`
  - `registerAddress(address,uint256)`
  - `registerAddress(address,bytes32,bytes)`
- Stable event:
  - `AddressRegistered`
- Added custom errors:
  - `JBAddressRegistry_AlreadyRegistered`
  - `JBAddressRegistry_NonceTooLarge`
  - `JBAddressRegistry_ZeroDeployer`
  - `JBAddressRegistry_AddressNotDeployed`

## Machine-Checked ABI Coverage

Generated from Foundry `out/**/*.json` artifacts, filtered to this repo's own runtime source roots and excluding tests, scripts, and dependencies.

- V5 comparison package: `nana-address-registry-v5`.
- Own-source ABI artifacts compared: V6 `2`, V5 `2`.
- Contract/interface coverage: `0` added, `0` removed, `1` shared names with ABI changes, `1` shared names ABI-identical.
- Shared-name ABI item deltas: `4` added, `0` removed, `0` modified.

Shared ABI artifacts with changes:
- `JBAddressRegistry`: `4` added, `0` removed, `0` modified ABI items.

Generated event/error name deltas:
- Error names added:
  - `JBAddressRegistry_AddressNotDeployed`, `JBAddressRegistry_AlreadyRegistered`, `JBAddressRegistry_NonceTooLarge`, `JBAddressRegistry_ZeroDeployer`.

Shared ABI artifacts checked with no ABI item changes:
- `IJBAddressRegistry`.

## Migration Notes

- Existing calldata for the two `registerAddress(...)` overloads remains structurally familiar, but callers should handle V6 custom errors.
- Review scripts that register predicted CREATE addresses. Nonce values that were silently mishandled or impossible to encode in V5 now fail explicitly.
