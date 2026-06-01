# Changelog

## Maintenance

- Raise dependency floors to the latest published versions, and document NatSpec, comment, and lint conventions in STYLE_GUIDE.

## Scope

This file describes the verified change from `nana-address-registry-v5` to the current `nana-address-registry-v6` repo.

## Current v6 surface

- `JBAddressRegistry`
- `IJBAddressRegistry`

## Summary

- Nonce handling is safer than in v5. The registry now guards against oversized nonces instead of silently producing the wrong derived address once the old encoding assumptions stopped holding.
- Zero-address deployers are explicitly rejected.
- The external surface remains intentionally small. This repo changed behavior more than shape.
- The repo moved from the v5 Solidity baseline to `0.8.28`.

## Verified deltas

- `_addressFrom(...)` now supports RLP nonce encoding through `uint64` instead of stopping at the old `uint32` path.
- `JBAddressRegistry_NonceTooLarge(uint256)` is thrown above that supported range.
- `JBAddressRegistry_ZeroDeployer()` is thrown when trying to register against `address(0)`.
- Duplicate registration now explicitly reverts with `JBAddressRegistry_AlreadyRegistered(address)`.

## Breaking ABI changes

- There is no meaningful function-selector migration here.
- The practical ABI-visible change is new custom errors that callers and tooling may need to decode.

## Indexer impact

- Event shape is effectively unchanged.
- The real migration concern is stricter revert behavior for previously tolerated bad inputs.

## Migration notes

- If you treated this repo as ABI-stable, that is mostly still true, but behavior around bad inputs is stricter.
- Recheck any tool that depended on silent high-nonce behavior. v6 makes that path explicit instead of permissive.

## Tooling

- Fixed the deployment configuration so the Sphinx proposal can validate and run. `foundry.toml` now emits the storage-layout build output (`extra_output = ['storageLayout']`) that Sphinx checks during proposal validation, and adds `[rpc_endpoints]` entries for every network the deploy script targets (Optimism, Base, Arbitrum, and the Ethereum/Optimism/Base/Arbitrum Sepolia testnets) so the proposal can connect. Previously only `ethereum` was configured, so the proposal failed before collecting any deployment transactions.
- Synced the `package-lock.json` version field with `package.json`; they had drifted apart.
