# Administration

## At A Glance

| Item | Details |
| --- | --- |
| Scope | Permissionless provenance registration for `CREATE` and `CREATE2` addresses |
| Control posture | Fully permissionless and adminless |
| Highest-risk actions | Incorrect first registration or bad derivation assumptions in offchain tooling |
| Recovery posture | No in-place recovery; replacement contract is the only fix for logic mistakes |

## Purpose

`nana-address-registry-v6` has no admin surface. It is a permissionless first-write provenance registry.

## Control Model

- no owner
- no governance
- no pause
- no upgrade
- registration is permissionless and correctness comes from deterministic address derivation

## Roles

| Role | How Assigned | Scope | Notes |
| --- | --- | --- | --- |
| Anyone | No assignment | Global | Can register an address if they provide correct `CREATE` or `CREATE2` inputs |

## Privileged Surfaces

There are no privileged functions. `registerAddress(...)` is permissionless for both registration paths.

## Immutable And One-Way

- registration is first-write only
- there is no overwrite or delete path for `deployerOf[address]`

## Operational Notes

- treat registration as provenance, not endorsement
- register addresses from trustworthy operational pipelines because bad first registration is sticky even though anyone can submit the correct derivation inputs

## Machine Notes

- do not treat registration as a safety certification or allowlist signal
- `src/JBAddressRegistry.sol` is the only control-relevant runtime file; there is no hidden owner path
- if offchain derivation and onchain registration disagree, resolve the derivation logic rather than assuming overwrite is possible

## Recovery

- there is no admin recovery surface
- if derivation logic were ever wrong, the contract would need replacement rather than intervention

## Admin Boundaries

- nobody can curate allowlists, edit entries, or block registration
- nobody can use this registry to certify code safety

## Source Map

- `src/JBAddressRegistry.sol`
- `src/interfaces/IJBAddressRegistry.sol`
- `script/Deploy.s.sol`
- `script/helpers/AddressRegistryDeploymentLib.sol`
- `test/JBAddressRegistry_Fork.t.sol`
- `test/regression/NonceTruncation.t.sol`
