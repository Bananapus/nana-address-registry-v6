# Juicebox Address Registry

`@bananapus/address-registry-v6` is a permissionless registry that records deployer provenance for contracts when callers provide matching `create` or `create2` deployment inputs. It is meant to make deployer provenance visible on-chain, especially for hooks and helper contracts that users may need to trust before interacting with them.

## Documentation

- [INVARIANTS.md](./INVARIANTS.md) — guarantees, operator powers, per-contract operation inventory, and cross-cutting invariants.
- [ARCHITECTURE.md](./ARCHITECTURE.md) — system overview, modules, trust boundaries, and critical flows.
- [ADMINISTRATION.md](./ADMINISTRATION.md) — control posture (none), roles, and recovery model.
- [RISKS.md](./RISKS.md) — risk register, with provenance-vs-safety as the P1 misuse risk.
- [USER_JOURNEYS.md](./USER_JOURNEYS.md) — registration and lookup flows for deployers, integrators, and auditors.
- [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md) — scope, critical invariants, and attack surfaces for auditors.
- [SKILLS.md](./SKILLS.md) — orientation map for AI agents working in this repo.
- [STYLE_GUIDE.md](./STYLE_GUIDE.md) — Solidity and repo conventions for the V6 ecosystem.
- [CHANGELOG.md](./CHANGELOG.md) - verified V5 to V6 deltas.

## Overview

The registry supports both `create` and `create2` deployments:

- for `create`, it reconstructs the deployed address from the deployer and nonce
- for `create2`, it reconstructs the deployed address from the deployer, salt, and deployment bytecode

Because the address is computed deterministically, registrations do not need access control. Anyone can submit the correct deployment inputs, and the registry records the deployer for the computed address after confirming code already exists there.

Use this repo when deployer provenance matters. Do not confuse it with an allowlist, review registry, or trust oracle.

## Key contract

| Contract | Role |
| --- | --- |
| `JBAddressRegistry` | Standalone registry that stores `deployerOf[address]` and exposes overloaded `registerAddress` entrypoints. |

## Mental model

The registry is intentionally narrow:

1. reconstruct an address from deployment inputs
2. bind that address to a deployer once
3. expose the result for other systems and clients

Anything beyond that is out of scope.

## Read these files first

1. `src/JBAddressRegistry.sol`
2. `test/JBAddressRegistry.t.sol`
3. `test/JBAddressRegistryEdge.t.sol`
4. `test/regression/RegressionFrontRunRegistrationDoS.t.sol`

## Integration traps

- provenance is only useful if callers also know what the deployer is trusted for
- permissionless registration is intentional, so integrations should verify the computed inputs rather than assume caller authority
- `create` nonce reconstruction and `create2` salt-bytecode reconstruction are different trust paths and should be reasoned about separately

## Where state lives

- deployer provenance: `JBAddressRegistry`
- deployment truth: the target chain history and bytecode inputs outside this repo

## High-signal tests

1. `test/JBAddressRegistry.t.sol`
2. `test/JBAddressRegistryEdge.t.sol`
3. `test/regression/RegressionUnauthorizedRegistrar.t.sol`

## Install

```bash
npm install @bananapus/address-registry-v6
```

## Development

```bash
npm install
forge build
forge test
```

Useful scripts:

- `npm run test:fork`
- `npm run deploy:mainnets`
- `npm run deploy:testnets`

## Deployment notes

The deploy script uses Sphinx for deterministic deployment. This package is intentionally small and independent because many other repos use it to record clone factories and helper deployments.

`script/Deploy.s.sol` targets Ethereum, Optimism, Base, and Arbitrum (plus their Sepolia testnets). For the Sphinx proposal to validate and run, `foundry.toml` must:

- enable the storage-layout build output (`extra_output = ['storageLayout']`), which Sphinx reads during proposal validation, and
- define an `[rpc_endpoints]` entry for each of those networks so the proposal can connect.

Provide the matching RPC URLs through environment variables before proposing or deploying:

- `RPC_ETHEREUM_MAINNET`, `RPC_OPTIMISM_MAINNET`, `RPC_BASE_MAINNET`, `RPC_ARBITRUM_MAINNET`
- `RPC_ETHEREUM_SEPOLIA`, `RPC_OPTIMISM_SEPOLIA`, `RPC_BASE_SEPOLIA`, `RPC_ARBITRUM_SEPOLIA`

## Repository layout

```text
src/
  JBAddressRegistry.sol
  interfaces/
test/
  unit, edge, fork, review, and regression coverage
script/
  Deploy.s.sol
  helpers/
```

## Risks and notes

- provenance is not the same as safety; a known deployer can still deploy unsafe code
- registrations are first-write only, so bad initial registration is sticky
- the `create` path relies on nonce reconstruction and intentionally rejects unrealistic nonce ranges

## For AI agents

- Describe this repo as a provenance registry, not as an allowlist or safety oracle.
- Read the edge and review tests before making claims about frontrunning or unauthorized registration.

If the question is "is this hook safe?" this repo can only tell you who deployed it, not whether the code is good.
