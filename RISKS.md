# Juicebox Address Registry Risk Register

This file focuses on what `JBAddressRegistry` actually proves: deterministic address provenance claims. The core risk is not funds loss inside the registry; it is consumers over-reading the meaning of a registration entry.

## How to use this file

- Read `Priority risks` first; most failures here are interpretive and integration-driven.
- Distinguish "address can be derived from these deployment inputs" from "this deployment is trusted".
- Treat `Invariants to Verify` as the narrow correctness envelope of the registry itself.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P1 | Over-trusting registration as safety approval | A registered deployer mapping does not mean the contract is audited, canonical, or safe. | UIs must label registration as provenance evidence only. |
| P1 | First-writer capture of a valid provenance claim | The registry records the first valid claim for an address and never updates it. | Operational discipline for trusted deployers and curated allowlists for consumers. |
| P2 | Completeness assumptions | Unregistered contracts can still be legitimate; absence from the registry is not a proof of malice. | Treat registry data as additive metadata, not an allowlist. |

## 1. Trust Assumptions

- **Deterministic address formulas.** The contract trusts its CREATE and CREATE2 address-derivation logic to match EVM semantics.
- **Consumer trust policy.** The registry does not decide which deployers are trusted. Every consumer must maintain that policy externally.

## 2. Known Risks

- **Caller identity is irrelevant.** Anyone may call `registerAddress(...)`. The registry proves that an address is consistent with supplied deployment parameters, not that the caller was the deployer.
- **First registration wins.** Once `deployerOf[addr]` is set, later registrations revert with `JBAddressRegistry_AlreadyRegistered`, even if a different valid provenance claim exists.
- **No pre-registration of future deployments.** `registerAddress(...)` requires `addr.code.length != 0`. The registry only records provenance for contracts that already exist on-chain; it cannot reserve a deterministic CREATE2 address ahead of deployment.
- **No removal or correction path.** The registry is intentionally append-only per address. Mistakes are sticky.
- **Registration is provenance, not endorsement.** A mapping like `deployerOf[hook] = someFactory` says nothing about code safety, upgradeability, audit status, or whether the deployer itself is trustworthy.
- **Operational lag matters.** If a trusted deployer forgets to register immediately, someone else can publish the first valid claim for that address.

## 3. Integration Risks

- **Frontends must pair registry data with a trusted-deployer set.** Displaying `deployerOf` without a trust list can mislead users into treating any registered provenance as "official".
- **CREATE and CREATE2 claims are both parameter-based.** In either mode, users should think "the address is compatible with these inputs", not "the registry witnessed deployment".
- **Off-chain explorers should preserve uncertainty.** A better label is "registered deployer claim" than "deployed by", unless the explorer independently verified the transaction history.

## 4. Invariants to Verify

- `deployerOf[addr]` is set at most once.
- CREATE registrations only succeed for addresses derivable from the provided `(deployer, nonce)`.
- CREATE2 registrations only succeed for addresses derivable from the provided `(deployer, salt, bytecode)`.
- `_addressFrom` remains correct for the supported nonce range and reverts outside that range.

## 5. Accepted Behaviors

### 5.1 The registry does not authenticate the registrant

This is intentional. `JBAddressRegistry` is a deterministic provenance registry, not a permissioned attestation service.

### 5.2 Unregistered does not mean unsafe

The registry is useful metadata, but it is not complete coverage of all legitimate deployments. Consumers should not infer that an unregistered address is malicious solely because no entry exists.

### 5.3 The registry is retrospective, not a reservation layer

This is intentional. A deterministic address can only be registered after code already exists there. Consumers should not expect `JBAddressRegistry` to signal future deployment intent or to protect an undeployed CREATE2 address from later first-writer capture once deployment happens.
