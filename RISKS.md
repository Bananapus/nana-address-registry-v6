# Juicebox Address Registry Risk Register

This file covers what `JBAddressRegistry` actually proves: deterministic address provenance claims. The main risk is not funds loss inside the registry. It is consumers reading too much into a registration entry.

## How To Use This File

- Read `Priority risks` first. Most failures here are interpretation and integration failures.
- Distinguish "address can be derived from these inputs" from "this deployment is trusted."
- Treat `Invariants to verify` as the narrow correctness envelope of the registry itself.

## Priority Risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P1 | Over-trusting registration as safety approval | A registered deployer mapping does not mean the contract is audited, canonical, or safe. | UIs should label registration as provenance evidence only. |
| P1 | First-writer capture of a valid provenance claim | The registry records the first valid claim for an address and never updates it. | Operational discipline for trusted deployers and curated allowlists for consumers. |
| P2 | Completeness assumptions | Unregistered contracts can still be legitimate; absence from the registry is not proof of malice. | Treat registry data as additive metadata, not an allowlist. |

## 1. Trust Assumptions

- **Deterministic address formulas are correct.** The contract trusts its `CREATE` and `CREATE2` derivation logic to match EVM semantics.
- **Consumers define trust externally.** The registry does not decide which deployers are trusted.

## 2. Known Risks

- **Caller identity is irrelevant.** Anyone may call `registerAddress(...)`. The registry proves that an address matches supplied deployment parameters, not that the caller was the deployer.
- **First registration wins.** Once `deployerOf[addr]` is set, later registrations revert.
- **No pre-registration of future deployments.** `registerAddress(...)` requires code to already exist at the computed address.
- **No removal or correction path.** The registry is intentionally append-only per address.
- **Registration is provenance, not endorsement.** `deployerOf[hook] = someFactory` says nothing about code safety, upgradeability, audit status, or whether the deployer itself is trustworthy.
- **Operational lag matters.** If a trusted deployer forgets to register immediately, someone else can publish the first valid claim for that address.

## 3. Integration Risks

- **Frontends should pair registry data with a trusted-deployer set.** Displaying `deployerOf` alone can mislead users into treating any registered provenance as official.
- **`CREATE` and `CREATE2` claims are parameter-based.** In either mode, the right mental model is "the address is compatible with these inputs," not "the registry witnessed deployment."
- **Off-chain explorers should preserve uncertainty.** "Registered deployer claim" is a safer label than "deployed by" unless the explorer also verified chain history.

## 4. Invariants To Verify

- `deployerOf[addr]` is set at most once
- `CREATE` registrations only succeed for addresses derivable from the provided `(deployer, nonce)`
- `CREATE2` registrations only succeed for addresses derivable from the provided `(deployer, salt, bytecode)`
- `_addressFrom` remains correct for the supported nonce range and reverts outside that range

## 5. Accepted Behaviors

### 5.1 The registry does not authenticate the registrant

This is intentional. `JBAddressRegistry` is a deterministic provenance registry, not a permissioned attestation service.

### 5.2 Unregistered does not mean unsafe

The registry is useful metadata, but it does not cover every legitimate deployment. Consumers should not infer that an unregistered address is malicious just because no entry exists.

### 5.3 The registry is retrospective, not a reservation layer

This is intentional. A deterministic address can only be registered after code already exists there. Consumers should not expect `JBAddressRegistry` to signal future deployment intent or protect an undeployed `CREATE2` address from later first-writer capture.
