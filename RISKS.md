# nana-address-registry-v6 — Risks

## Trust Assumptions

1. **Self-Registration** — Anyone can register any address. The registry does NOT verify that the caller actually deployed the contract. It only verifies that the computed address matches the provided parameters.
2. **Address Computation** — Relies on correct RLP encoding (create) and keccak256 (create2) for address derivation. Standard Ethereum address computation.
3. **Frontend Trust** — Frontends must maintain their own list of trusted deployers. The registry only provides the mapping, not a trust judgment.

## Known Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| False registration | Anyone can call registerAddress — the computed address must match, but the "deployer" parameter is not verified as the actual deployer | Address computation ensures the deployer/nonce pair produced the address |
| Overwrite | A second registration for the same address overwrites the first | By design; last writer wins |
| No unregister | Once registered, a deployer mapping cannot be removed | Intentional; provides permanent provenance |
| Nonce range | Supports nonces up to uint64 max | Covers any realistic Ethereum nonce |

## Privileged Roles

None — the contract is fully permissionless. Anyone can register, anyone can query.
