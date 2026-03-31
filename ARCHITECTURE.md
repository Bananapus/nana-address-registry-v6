# Architecture

## Purpose

`nana-address-registry-v6` is a tiny trust-attestation primitive. It records who deployed a contract by recomputing the deployed address from CREATE or CREATE2 inputs and storing the verified deployer on-chain.

## Boundaries

- The repo does not assess contract safety.
- It does not manage upgrades, ownership, or deployment permissions.
- It only answers one question: "which deployer could have created this address?"

## Main Components

| Component | Responsibility |
| --- | --- |
| `JBAddressRegistry` | Verifies deterministic address derivation and stores `deployerOf[address]` |
| `IJBAddressRegistry` | Minimal public interface for registration and lookup |

## Runtime Model

```text
caller
  -> provides deployer plus CREATE nonce or CREATE2 salt+bytecode
  -> registry recomputes the target address
  -> registry stores the deployer for that address if it was not already registered
```

## Critical Invariants

- Registration is permissionless because correctness comes from deterministic address derivation, not caller authority.
- Re-registration must stay impossible.
- CREATE and CREATE2 derivations must match EVM address derivation exactly; this repo is useless if the reconstruction is even slightly wrong.

## Where Complexity Lives

- Almost all of the risk is concentrated in a tiny amount of derivation logic.
- The repo is simple enough that overengineering is a bigger risk than underengineering.

## Dependencies

- None that matter semantically beyond Solidity's address derivation rules

## Safe Change Guide

- Treat derivation logic as cryptographic plumbing. Prefer no change over clever change.
- If you touch nonce handling or bytecode hashing, add or retain tests for both CREATE and CREATE2 paths.
- Do not turn this registry into a trust oracle. Keep the scope narrow.
