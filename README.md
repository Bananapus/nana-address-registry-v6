# Juicebox Address Registry

`@bananapus/address-registry-v6` is a permissionless registry that records which deployer created a contract. It is meant to make deployer provenance visible on-chain, especially for hooks and helper contracts that users may need to trust before interacting with them.

Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)

## Overview

The registry supports both `create` and `create2` style deployments:

- for `create`, it reconstructs the deployed address from the deployer and nonce
- for `create2`, it reconstructs the deployed address from the deployer, salt, and deployment bytecode

Because the address is computed deterministically, registrations do not require access control. Anyone can submit the correct deployment inputs, and the registry records the verified deployer for the computed address.

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

Anything beyond that is out of scope by design.

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

- provenance is not the same thing as safety; a known deployer can still deploy unsafe code
- registrations are first-write only, so bad operational processes around initial registration can be sticky
- the `create` address path relies on nonce reconstruction and intentionally rejects unrealistic nonce ranges
