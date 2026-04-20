# Juicebox Address Registry

`@bananapus/address-registry-v6` is a permissionless registry that records deployer provenance for contracts when callers provide matching `create` or `create2` deployment inputs. It is meant to make deployer provenance visible on-chain, especially for hooks and helper contracts that users may need to trust before interacting with them.

Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)  
User journeys: [USER_JOURNEYS.md](./USER_JOURNEYS.md)  
Skills: [SKILLS.md](./SKILLS.md)  
Risks: [RISKS.md](./RISKS.md)  
Administration: [ADMINISTRATION.md](./ADMINISTRATION.md)  
Audit instructions: [AUDIT_INSTRUCTIONS.md](./AUDIT_INSTRUCTIONS.md)

## Overview

The registry supports both `create` and `create2` deployments:

- for `create`, it reconstructs the deployed address from the deployer and nonce
- for `create2`, it reconstructs the deployed address from the deployer, salt, and deployment bytecode

Because the address is computed deterministically, registrations do not need access control. Anyone can submit the correct deployment inputs, and the registry records the deployer for the computed address after confirming code already exists there.

Use this repo when deployer provenance matters. Do not confuse it with an allowlist, audit registry, or trust oracle.

If the question is "is this hook safe?" this repo can only tell you who deployed it, not whether the code is good.

## Key Contract

| Contract | Role |
| --- | --- |
| `JBAddressRegistry` | Standalone registry that stores `deployerOf[address]` and exposes overloaded `registerAddress` entrypoints. |

## Mental Model

The registry is intentionally narrow:

1. reconstruct an address from deployment inputs
2. bind that address to a deployer once
3. expose the result for other systems and clients

Anything beyond that is out of scope.

## Read These Files First

1. `src/JBAddressRegistry.sol`
2. `test/JBAddressRegistry.t.sol`
3. `test/JBAddressRegistryEdge.t.sol`
4. `test/audit/CodexFrontRunRegistrationDoS.t.sol`

## Integration Traps

- provenance is only useful if callers also know what the deployer is trusted for
- permissionless registration is intentional, so integrations should verify the computed inputs rather than assume caller authority
- `create` nonce reconstruction and `create2` salt-bytecode reconstruction are different trust paths and should be reasoned about separately

## Where State Lives

- deployer provenance: `JBAddressRegistry`
- deployment truth: the target chain history and bytecode inputs outside this repo

## High-Signal Tests

1. `test/JBAddressRegistry.t.sol`
2. `test/JBAddressRegistryEdge.t.sol`
3. `test/audit/CodexUnauthorizedRegistrar.t.sol`

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

## Deployment Notes

The deploy script uses Sphinx for deterministic deployment. This package is intentionally small and independent because many other repos use it to record clone factories and helper deployments.

## Repository Layout

```text
src/
  JBAddressRegistry.sol
  interfaces/
test/
  unit, edge, fork, audit, and regression coverage
script/
  Deploy.s.sol
  helpers/
```

## Risks And Notes

- provenance is not the same as safety; a known deployer can still deploy unsafe code
- registrations are first-write only, so bad initial registration is sticky
- the `create` path relies on nonce reconstruction and intentionally rejects unrealistic nonce ranges

## For AI Agents

- Describe this repo as a provenance registry, not as an allowlist or safety oracle.
- Read the edge and audit tests before making claims about frontrunning or unauthorized registration.
