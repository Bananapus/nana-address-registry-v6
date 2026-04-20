# Juicebox Address Registry

## Use This File For

- Use this file when the task involves deployer provenance, `create` or `create2` registration logic, or determining what the registry does and does not prove.
- Start here, then decide whether the issue is `create` address derivation, `create2` derivation, or misuse of provenance as a trust signal.

## Read This Next

| If you need... | Open this next |
|---|---|
| Repo overview and intended guarantees | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Registry implementation | [`src/JBAddressRegistry.sol`](./src/JBAddressRegistry.sol) |
| Runtime and operational assumptions | [`references/runtime.md`](./references/runtime.md), [`references/operations.md`](./references/operations.md) |
| Interfaces and deployment | [`src/interfaces/`](./src/interfaces/), [`script/Deploy.s.sol`](./script/Deploy.s.sol) |
| Edge and fork coverage | [`test/JBAddressRegistry.t.sol`](./test/JBAddressRegistry.t.sol), [`test/JBAddressRegistryEdge.t.sol`](./test/JBAddressRegistryEdge.t.sol), [`test/JBAddressRegistry_Fork.t.sol`](./test/JBAddressRegistry_Fork.t.sol) |

## Repo Map

| Area | Where to look |
|---|---|
| Main contract | [`src/JBAddressRegistry.sol`](./src/JBAddressRegistry.sol) |
| Interfaces | [`src/interfaces/`](./src/interfaces/) |
| Scripts | [`script/`](./script/) |
| Tests | [`test/`](./test/) |

## Purpose

Permissionless on-chain provenance registry that records which deployer created a contract by reconstructing deterministic `create` or `create2` addresses from the supplied deployment inputs.

## Reference Files

- Open [`references/runtime.md`](./references/runtime.md) when you need the core guarantees, first-write semantics, or the difference between provenance and trust.
- Open [`references/operations.md`](./references/operations.md) when you need deployment breadcrumbs, test pointers, or common stale assumptions about what the registry can verify.

## Working Rules

- Start in [`src/JBAddressRegistry.sol`](./src/JBAddressRegistry.sol). This repo is intentionally small, so most questions should collapse quickly to the core contract.
- Treat provenance and safety as separate questions. The registry only proves who deployed something.
- Registration is first-write only and requires code to already exist at the computed address.
- When a task involves wrong or missing registry data, verify the registration inputs before assuming a contract bug.
