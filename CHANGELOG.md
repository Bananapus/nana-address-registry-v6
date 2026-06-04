# Changelog

## Scope

This file describes the verified change from `nana-address-registry-v5` to `nana-address-registry-v6`.

## v6 surface

- `JBAddressRegistry`
- `IJBAddressRegistry`

## Summary

- v6 guards against oversized nonces; v5 silently produced the wrong derived address once its encoding assumptions no longer held.
- v6 explicitly rejects zero-address deployers.
- The external surface stays intentionally small; v6 differs from v5 in behavior more than in shape.
- v6 builds against Solidity `0.8.28`; v5 builds against the v5 Solidity baseline.

## Behavior deltas

- `_addressFrom(...)` derives `CREATE` addresses through the full `uint64` nonce range in v6; v5 stops at `uint32`.
- `JBAddressRegistry_NonceTooLarge(uint256)` reverts above the supported range.
- `JBAddressRegistry_ZeroDeployer()` reverts when registering against `address(0)`.
- Duplicate registration reverts with `JBAddressRegistry_AlreadyRegistered(address)`.

## ABI deltas

- No function-selector migration.
- The ABI-visible delta is the new custom errors that callers and tooling decode.

## Indexer impact

- Event shape is unchanged between v5 and v6.
- The migration concern is v6's stricter revert behavior for inputs v5 tolerated.

## Migration notes

- If you treated this repo as ABI-stable, that mostly holds; v6 is stricter around bad inputs.
- Recheck any tool that depended on v5's silent high-nonce behavior. v6 reverts on that path instead.

## Repo housekeeping

- Dependency floors track the latest published versions, and STYLE_GUIDE documents the NatSpec, comment, and lint conventions.
- `foundry.toml` emits the storage-layout build output (`extra_output = ['storageLayout']`) that Sphinx reads during proposal validation, and defines `[rpc_endpoints]` for every network the deploy script targets (Optimism, Base, Arbitrum, and the Ethereum/Optimism/Base/Arbitrum Sepolia testnets) so the Sphinx proposal can validate, connect, and collect deployment transactions across all of them.
- The `package-lock.json` version field matches `package.json`.
