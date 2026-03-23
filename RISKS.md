# RISKS.md -- nana-address-registry-v6

## 1. Trust Assumptions

- **Self-registration.** Anyone can register any address. The registry does NOT verify that the caller actually deployed the contract. It only verifies that the computed address matches the provided deployer/nonce or deployer/salt/bytecode parameters.
- **Frontend trust.** Frontends must maintain their own list of trusted deployers. The registry provides the mapping, not a trust judgment.

## 2. Known Risks

- **False registration.** Anyone can call `registerAddress` with arbitrary deployer/nonce values, registering a computed address with a deployer that did not actually deploy it. Consumers must verify the deployer is trusted, not just that a mapping exists.
- **Overwrite of existing entries.** There is no check preventing re-registration. A second call with different parameters that computes the same address will overwrite the previous `deployerOf` entry.
- **No removal mechanism.** Once registered, an entry cannot be removed, only overwritten.
- **CREATE2 vs CREATE1 trust model.** CREATE1 registrations (`registerAddress(deployer, nonce)`) can be spoofed: anyone who knows the deployer address and nonce can register the computed address without being the deployer. CREATE2 registrations (`registerAddress(deployer, salt, bytecodeHash)`) have the same trust model — knowing the parameters is sufficient to register. In both cases, the registry only proves "this address COULD have been deployed by this deployer with these parameters", not "this deployer DID deploy this address". Consumers must verify the deployer is trusted independently.
- **Frontend trust example.** A malicious actor could register `deployerOf[uniswapRouter] = attackerDeployer` if they find a `(deployer, nonce)` or `(deployer, salt, bytecodeHash)` combination that computes to the Uniswap router address. The overwrite succeeds because there is no owner check. Frontends that display "deployed by X" based on `deployerOf` should cross-reference against a curated allowlist of trusted deployers.

## 3. Invariants to Verify

- `deployerOf[addr]` always corresponds to a valid deployer/nonce pair that produces `addr` (if registered via `registerAddress`).
- `create2` registrations: `deployerOf[addr]` corresponds to a valid deployer/salt/bytecodeHash that produces `addr`.
- Overwrite consistency: after any `registerAddress` call, `deployerOf[addr]` reflects the LAST registration, not the first. Earlier registrations are silently replaced.

## 4. Accepted Behaviors

### 4.1 RLP encoding correctness is well-tested and bounded

The `_addressFrom` function manually implements RLP encoding for nonces up to uint64. The nonce is capped at uint64 max with an explicit revert, and the encoding logic is a well-tested pattern. This is not an open risk.
