# Audit Instructions

This repo is a small registry, but it participates in deployer verification across the ecosystem. Treat incorrect registration as a security boundary failure.

## Audit Objective

Find issues that:
- let callers register contracts under the wrong deployer
- break determinism or uniqueness assumptions around registration
- let a malicious deployer spoof provenance for contracts it did not create
- create stale or truncation-related collisions in recorded mappings

## Scope

In scope:
- `src/JBAddressRegistry.sol`
- `src/interfaces/IJBAddressRegistry.sol`
- all deployment helpers in `script/`

## Start Here

1. `src/JBAddressRegistry.sol`
2. `script/Deploy.s.sol`

## Security Model

The registry maps deployed addresses to the deployer that created them. Downstream repos use it to:
- validate provenance for clones or deterministically deployed instances
- discover whether a contract came from an approved deployer path

## Roles And Privileges

| Role | Powers | How constrained |
|------|--------|-----------------|
| Deployer | Register contracts as its outputs | Must prove authentic deployment provenance |
| Registry reader | Trust provenance for privileged decisions | Must not observe spoofable or mutable history |

## Integration Assumptions

| Dependency | Assumption | What breaks if wrong |
|------------|------------|----------------------|
| Approved deployers | Produce the addresses they claim | Downstream provenance gates become meaningless |

## Critical Invariants

1. Provenance cannot be forged
Only the actual deployer path the registry intends to trust may create a successful registration for a contract.

2. One contract maps to one authoritative deployer record
No aliasing or overwrite path should let a later caller replace provenance unexpectedly.

3. Registration metadata is stable
Nonce, salt, or address truncation must not allow collisions or stale reads.

## Attack Surfaces

- registration entrypoints that rely on deployer provenance
- overwrite and replay paths
- deterministic deployment assumptions
- zero-address or malformed registration attempts

## Verification

- `npm install`
- `forge build`
- `forge test`
