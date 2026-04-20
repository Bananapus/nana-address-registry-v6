# Administration

## At A Glance

| Item | Details |
| --- | --- |
| Scope | Permissionless provenance registration for CREATE and CREATE2 addresses |
| Control posture | Fully permissionless and adminless |
| Highest-risk actions | Incorrect first registration or bad derivation assumptions in offchain tooling |
| Recovery posture | No in-place recovery; replacement contract is the only fix for logic mistakes |

## Purpose

`nana-address-registry-v6` has no admin surface. It is a permissionless first-write provenance registry.

## Control Model

- No owner
- No governance
- No pause
- No upgrade
- Registration is permissionless and correctness comes from deterministic address derivation

## Roles

| Role | How Assigned | Scope | Notes |
| --- | --- | --- | --- |
| Anyone | No assignment | Global | Can register an address if they provide correct CREATE or CREATE2 inputs |

## Privileged Surfaces

There are no privileged functions. `registerAddress(...)` is permissionless for both CREATE and CREATE2 registration paths.

## Immutable And One-Way

- Registration is first-write only.
- There is no overwrite or delete path for `deployerOf[address]`.

## Operational Notes

- Treat registration as provenance, not endorsement.
- Register addresses from trustworthy operational pipelines because bad first registration is sticky even though anyone can submit the correct derivation inputs.

## Machine Notes

- Do not treat registration as a safety certification or allowlist signal.
- `src/JBAddressRegistry.sol` is the only control-relevant runtime file; there is no hidden owner path.
- If offchain derivation and onchain registration disagree, stop and resolve the derivation logic rather than assuming overwrite is possible.

## Recovery

- There is no admin recovery surface.
- If derivation logic were ever wrong, the contract would need replacement rather than intervention.

## Admin Boundaries

- Nobody can curate allowlists, edit entries, or block registration.
- Nobody can use this registry to certify code safety.

## Source Map

- `src/JBAddressRegistry.sol`
- `src/interfaces/IJBAddressRegistry.sol`
- `script/Deploy.s.sol`
- `script/helpers/AddressRegistryDeploymentLib.sol`
- `test/JBAddressRegistry_Fork.t.sol`
- `test/regression/NonceTruncation.t.sol`
