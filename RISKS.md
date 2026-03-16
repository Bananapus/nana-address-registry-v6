# RISKS.md -- nana-address-registry-v6

## 1. Trust Assumptions

- **Self-registration.** Anyone can register any address. The registry does NOT verify that the caller actually deployed the contract. It only verifies that the computed address matches the provided deployer/nonce or deployer/salt/bytecode parameters.
- **Frontend trust.** Frontends must maintain their own list of trusted deployers. The registry provides the mapping, not a trust judgment.

## 2. Known Risks

- **False registration.** Anyone can call `registerAddress` with arbitrary deployer/nonce values, registering a computed address with a deployer that did not actually deploy it. Consumers must verify the deployer is trusted, not just that a mapping exists.
- **Overwrite of existing entries.** There is no check preventing re-registration. A second call with different parameters that computes the same address will overwrite the previous `deployerOf` entry.
- **No removal mechanism.** Once registered, an entry cannot be removed, only overwritten.
- **RLP encoding correctness.** The `_addressFrom` function manually implements RLP encoding for nonces up to uint64. Well-tested pattern; nonce capped at uint64 max with explicit revert.

## 3. Invariants to Verify

- `deployerOf[addr]` always corresponds to a valid deployer/nonce pair that produces `addr` (if registered via `registerAddress`).
- `create2` registrations: `deployerOf[addr]` corresponds to a valid deployer/salt/bytecodeHash that produces `addr`.
