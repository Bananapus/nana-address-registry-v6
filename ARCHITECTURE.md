# Architecture

## Purpose

`nana-address-registry-v6` is a small provenance primitive. It records which deployer could have created a contract address by recomputing `CREATE` or `CREATE2` inputs and storing the verified result on-chain.

## System Overview

The repo is intentionally small. `JBAddressRegistry` accepts deterministic deployment inputs, reconstructs the resulting address, and records the deployer if that address has not already been registered. It does not judge code safety, manage upgrades, or gate deployments.

## Core Invariants

- registration is permissionless because correctness comes from deterministic derivation, not caller authority
- a contract address can only be registered once
- registration must fail until runtime code actually exists at the derived address
- `CREATE` and `CREATE2` derivation must match EVM rules exactly

## Modules

| Module | Responsibility | Notes |
| --- | --- | --- |
| `JBAddressRegistry` | Address derivation and first-write provenance storage | Main contract |
| `IJBAddressRegistry` | Minimal lookup and registration interface | External surface |

## Trust Boundaries

- the registry attests to deterministic provenance, not code quality
- it does not manage ownership, upgrades, or allowlists
- external systems may trust its recorded provenance, so derivation correctness is the whole product

## Critical Flows

### Register

```text
caller
  -> supplies deployer plus CREATE nonce or CREATE2 salt and bytecode
  -> registry recomputes the target address
  -> registry records the deployer if the address was previously unregistered
```

## Accounting Model

No economic accounting lives here. The only important state is `deployerOf[address]`.

## Security Model

- the risk is concentrated in a small amount of address-derivation logic
- the registry records the derived deployer, not the transaction caller
- overengineering is more dangerous than minimal, auditable derivation code

## Safe Change Guide

- treat derivation code like cryptographic plumbing
- keep the undeployed-address check and first-write-only rule intact
- if nonce handling or bytecode hashing changes, keep `CREATE` and `CREATE2` tests aligned
- do not expand the repo into an allowlist or trust-oracle system

## Canonical Checks

- `CREATE` and `CREATE2` derivation correctness:
  `test/JBAddressRegistry.t.sol`
- edge-path validation and first-write behavior:
  `test/JBAddressRegistryEdge.t.sol`
- pre-registration, frontrun, and undeployed-code defenses:
  `test/audit/CodexFrontRunRegistrationDoS.t.sol`
- provenance abuse and zero-deployer edge cases:
  `test/audit/CodexUnauthorizedRegistrar.t.sol`
  `test/audit/ZeroDeployerRegistration.t.sol`

## Source Map

- `src/JBAddressRegistry.sol`
- `src/interfaces/IJBAddressRegistry.sol`
- `test/JBAddressRegistry.t.sol`
- `test/JBAddressRegistryEdge.t.sol`
- `test/audit/CodexFrontRunRegistrationDoS.t.sol`
- `test/audit/CodexUnauthorizedRegistrar.t.sol`
- `test/audit/ZeroDeployerRegistration.t.sol`
- `test/regression/NonceTruncation.t.sol`
- `script/Deploy.s.sol`
- `script/helpers/AddressRegistryDeploymentLib.sol`
- `references/runtime.md`
- `references/operations.md`
