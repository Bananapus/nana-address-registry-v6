# RISKS.md -- nana-address-registry-v6

## 1. Trust Assumptions

- **Self-registration.** Anyone can register any address. The registry does NOT verify that the caller actually deployed the contract. It only verifies that the computed address matches the provided deployer/nonce or deployer/salt/bytecode parameters.
- **Frontend trust.** Frontends must maintain their own list of trusted deployers. The registry provides the mapping, not a trust judgment.

## 2. Known Risks

- **False registration.** Anyone can call `registerAddress` with arbitrary deployer/nonce values, registering a computed address with a deployer that did not actually deploy it. Consumers must verify the deployer is trusted, not just that a mapping exists.
- **No removal mechanism.** Once registered, an entry cannot be removed. Re-registration of the same address reverts with `JBAddressRegistry_AlreadyRegistered`.
- **CREATE2 vs CREATE1 trust model.** CREATE1 registrations (`registerAddress(deployer, nonce)`) can be spoofed: anyone who knows the deployer address and nonce can register the computed address without being the deployer. CREATE2 registrations (`registerAddress(deployer, salt, bytecode)`) have the same trust model — knowing the parameters is sufficient to register. The function accepts raw deployment bytecode and hashes it internally (`keccak256(bytecode)`) for the CREATE2 address computation. In both cases, the registry only proves "this address COULD have been deployed by this deployer with these parameters", not "this deployer DID deploy this address". Consumers must verify the deployer is trusted independently.
- **Frontend trust example.** A malicious actor could register `deployerOf[uniswapRouter] = attackerDeployer` if they find a `(deployer, nonce)` or `(deployer, salt, bytecode)` combination that computes to the Uniswap router address and register it before the legitimate deployer does. Only the first registration is accepted; subsequent attempts revert with `JBAddressRegistry_AlreadyRegistered`. Frontends that display "deployed by X" based on `deployerOf` should cross-reference against a curated allowlist of trusted deployers.

## 3. Invariants to Verify

- `deployerOf[addr]` always corresponds to a valid deployer/nonce pair that produces `addr` (if registered via `registerAddress`).
- `create2` registrations: `deployerOf[addr]` corresponds to a valid deployer/salt/bytecode combination whose `keccak256(bytecode)` produces `addr` via the CREATE2 formula.
- Registration idempotency: `deployerOf[addr]` reflects the first and only registration. Subsequent attempts to register the same address revert with `JBAddressRegistry_AlreadyRegistered`.

## 4. Accepted Behaviors

### 4.1 RLP encoding correctness is well-tested and bounded

The `_addressFrom` function manually implements RLP encoding for nonces up to uint64. The nonce is capped at uint64 max with an explicit revert, and the encoding logic is a well-tested pattern. This is not an open risk.
