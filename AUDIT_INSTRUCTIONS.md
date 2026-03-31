# Audit Instructions

This repo is a small registry, but it participates in deployer verification across the ecosystem. Treat incorrect registration as a security boundary failure.

## Objective

Find issues that:
- let callers register contracts under the wrong deployer
- break determinism or uniqueness assumptions around registration
- let a malicious deployer spoof provenance for contracts it did not create
- create stale or truncation-related collisions in recorded mappings

## Scope

In scope:
- `src/JBAddressRegistry.sol`
- `src/interfaces/IJBAddressRegistry.sol`
- deployment scripts in `script/`

## System Model

The registry maps deployed addresses to the deployer that created them. Downstream repos use it to:
- validate provenance for clones or deterministically deployed instances
- discover whether a contract came from an approved deployer path

## Critical Invariants

1. Provenance cannot be forged
Only the actual deployer path the registry intends to trust may create a successful registration for a contract.

2. One contract maps to one authoritative deployer record
No aliasing or overwrite path should let a later caller replace provenance unexpectedly.

3. Registration metadata is stable
Nonce, salt, or address truncation must not allow collisions or stale reads.

## Threat Model

Prioritize:
- zero-address or malformed registration attempts
- deterministic deployment edge cases
- overwrite or replay behavior
- any assumption that `msg.sender` is sufficient proof without deployment linkage

## Build And Verification

Standard workflow:
- `npm install`
- `forge build`
- `forge test`

Tests already focus on zero deployers and nonce-truncation regressions. A meaningful finding here should show downstream trust in the registry becoming misplaced, not just a cosmetic mismatch.
