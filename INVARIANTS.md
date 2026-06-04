# Invariants of `nana-address-registry-v6`

Scope: the `JBAddressRegistry` contract — a permissionless, adminless, first-write provenance registry that maps deployed contract addresses to the deployer that produced them. The repo ships exactly one contract (`src/JBAddressRegistry.sol`, ~150 lines) and one interface (`src/interfaces/IJBAddressRegistry.sol`). There is no owner, no upgrade path, no pause, no allowlist.

| Item | Value |
|---|---|
| Contract | `JBAddressRegistry` |
| State | `mapping(address => address) deployerOf` |
| Entrypoints | `registerAddress(deployer, nonce)` and `registerAddress(deployer, salt, bytecode)` |
| Lookup | `deployerOf(addr) view → deployer` |
| Event | `AddressRegistered(addr indexed, deployer indexed, caller)` |
| Errors | `JBAddressRegistry_AlreadyRegistered`, `JBAddressRegistry_NonceTooLarge`, `JBAddressRegistry_ZeroDeployer`, `JBAddressRegistry_AddressNotDeployed` |

What this registry **does**: confirms that a target address is exactly the address produced by the supplied `CREATE` / `CREATE2` inputs, that runtime code already lives at that address, and binds a single deployer record to it.

What this registry **does not**: vouch for code safety, audit status, governance approval, or claim that the registering caller is the deployer. The registering caller's identity is intentionally irrelevant.

---

## Section A — Guarantees to users (registrants and consumers)

## A.1 Registration determinism

- A successful `registerAddress(deployer, nonce)` proves that the registered address is exactly the address EVM `CREATE` semantics would produce for `(deployer, nonce)`. Derivation uses RLP encoding through the full `uint64` nonce range.
- A successful `registerAddress(deployer, salt, bytecode)` proves that the registered address is exactly `keccak256(0xff || deployer || salt || keccak256(bytecode))[12:]` — standard `CREATE2`.
- The registry never records a deployer for an address that does not match the supplied inputs. Mismatched inputs revert (or land on a different address that does not match the intended contract).

## A.2 Address-already-deployed requirement

- Registration reverts with `JBAddressRegistry_AddressNotDeployed` unless `addr.code.length > 0` at the moment of the call.
- The registry is **retrospective only**: it cannot reserve provenance for an undeployed `CREATE2` address. Consumers cannot use it as a future-deployment commitment.

## A.3 First-write-only / sticky binding

- For every address, `deployerOf[addr]` is set at most once. Subsequent registrations revert with `JBAddressRegistry_AlreadyRegistered(addr)`.
- No path exists in the contract to clear, overwrite, or correct `deployerOf[addr]`. A bad first registration is permanent.
- `deployerOf` is also rejected for `address(0)` deployers (`JBAddressRegistry_ZeroDeployer`), so `deployerOf[addr] == address(0)` unambiguously means "unregistered."

## A.4 Caller authority

- Anyone can call either `registerAddress` overload. The caller is **not** authenticated; the registry attests to deployment inputs, not to caller identity.
- The `AddressRegistered` event carries `caller = msg.sender` as informational metadata. It is not part of the trust claim.

## A.5 What consumers MAY infer from a registration

- `deployerOf[addr] = D` means: at some point, runtime code existed at `addr`, and `addr` is consistent with `D` having produced it via `CREATE` or `CREATE2`.
- Consumers can pair this with an external trust list (e.g., "is `D` an approved factory?") to gate downstream behavior.

## A.6 What consumers MUST NOT infer

- A registration does **not** mean the contract code is safe, audited, canonical, or endorsed.
- A registration does **not** mean the caller of `registerAddress` is the deployer.
- An **absent** registration does **not** mean an address is malicious or untrusted; it may simply be unregistered.
- A registration does **not** guarantee the runtime code is still the same code present at registration time (the contract could have been self-destructed in pre-Cancun deployments; for `CREATE2` the same address could have been re-deployed if originally selfdestructed — though `deployerOf` would already be set and prevent a re-registration).

---

## Section B — Operator / admin powers

There is no operator or admin.

- No `owner`. No `Ownable`, `Ownable2Step`, or governance role.
- No `pause` / `unpause`. No emergency switch.
- No `upgrade` / proxy. The contract is deployed once and is immutable.
- No allowlist of deployers. No registry curation.
- No removal / overwrite / correction surface.

**The contract has zero privileged functions.** Recovery from a bad registration or a derivation bug is not possible in-place — only by deploying a replacement contract, which downstream consumers would have to migrate to.

---

## Section C — Per-contract operation inventory

## C.1 `JBAddressRegistry` — `src/JBAddressRegistry.sol`

### External / public functions

- **`registerAddress(address deployer, uint256 nonce)`** — permissionless. (`src/JBAddressRegistry.sol:50-56`)
  - Computes the `CREATE` address from `(deployer, nonce)` via RLP encoding, then delegates to `_registerAddress`.
  - **Invariant:** reverts `JBAddressRegistry_NonceTooLarge(nonce)` when `nonce > type(uint64).max`; reverts `JBAddressRegistry_ZeroDeployer` when `deployer == 0`; reverts `JBAddressRegistry_AddressNotDeployed` when no code at the derived address; reverts `JBAddressRegistry_AlreadyRegistered` when the slot is already set.
  - **Cannot:** register an address whose `CREATE` derivation does not match the inputs; overwrite an existing record.

- **`registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)`** — permissionless. (`src/JBAddressRegistry.sol:66-73`)
  - Computes the `CREATE2` address as `keccak256(0xff || deployer || salt || keccak256(bytecode))[12:]`, then delegates to `_registerAddress`.
  - **Invariant:** same guards as the `CREATE` overload (zero deployer, code-present, not-already-registered).
  - **Cannot:** register an address whose `CREATE2` derivation does not match the inputs; reserve provenance ahead of code being deployed.

- **`deployerOf(address addr) external view returns (address)`** — autogenerated by `public` mapping. (`src/JBAddressRegistry.sol:40`)
  - Returns the deployer recorded for `addr`, or `address(0)` if none recorded.
  - **Invariant:** read-only; one storage slot per address.

### Internal helpers

- **`_registerAddress(address addr, address deployer)`** — (`src/JBAddressRegistry.sol:82-93`)
  - Enforces the three core guards in order: non-zero deployer, code present at `addr`, slot empty.
  - Writes `deployerOf[addr] = deployer` and emits `AddressRegistered(addr, deployer, msg.sender)`.

- **`_addressFrom(address origin, uint256 nonce) pure returns (address)`** — (`src/JBAddressRegistry.sol:104-148`)
  - RLP-encodes `[origin, nonce]` across nine width branches (0, 1B, 2B, 3B, 4B, 5B, 6B, 7B, 8B nonce payloads) and hashes.
  - **Invariant:** matches EVM `CREATE` address derivation for any `nonce ≤ type(uint64).max`. Reverts above that range via the public entrypoint guard.

### Events

- **`AddressRegistered(address indexed addr, address indexed deployer, address caller)`** — emitted exactly once per address, at the moment `deployerOf[addr]` is set.

---

## Section D — Cross-cutting invariants

## D.1 State minimality

- The contract holds exactly one mutable storage variable: `mapping(address => address) deployerOf`. No counters, no arrays, no inverse index, no per-deployer enumeration.
- There are no upgradeable storage slots, no proxy, no init function.

## D.2 Determinism of derivation

- `CREATE` derivation matches the standard EVM rule for the entire valid nonce range `[0, 2^64 − 1]`. Out-of-range values revert rather than silently truncating.
- `CREATE2` derivation matches EIP-1014 exactly (`0xff || deployer || salt || keccak256(bytecode)`). The full deployment bytecode (including constructor args) must be provided; an init-code-hash-only path is not supported.
- The derivation paths are independent: a given `addr` could match either a `CREATE` or `CREATE2` input set; whichever is registered first wins.

## D.3 First-write monotonicity

- Once written, `deployerOf[addr]` is monotonically stable: it never changes value and never reverts to `address(0)`.
- The `AddressRegistered` event is therefore emitted at most once per `addr` over the contract's lifetime.

## D.4 Liveness

- Registration cannot be DoS'd by a third party against a deployer who is willing to register their own deployments promptly: the only "blocking" path is another caller front-running with the **correct** inputs, which is observable and produces the same `deployerOf[addr]` value the genuine deployer would have produced. Front-running with **incorrect** inputs cannot succeed.
- An attacker cannot bind a deployer-of-record to a contract that deployer did not actually produce, because the derivation must match an address with on-chain code.

## D.5 Out-of-scope concerns (deliberately)

- The registry does not detect or react to `SELFDESTRUCT`. A subsequent re-deployment to the same address (only possible via `CREATE2` with the originally-selfdestructed init code) would not be reflected; the original `deployerOf[addr]` record persists.
- The registry does not version code. A proxy whose implementation rotates is registered against the proxy's deployer, not the implementation's.
- The registry does not verify constructor arguments beyond their effect on the derived address (for `CREATE2`) or the nonce (for `CREATE`).

---

## Section E — Centralization and trust assumptions

## E.1 Centralization risks

**None at the contract level.** `JBAddressRegistry` is adminless. There is no owner, multisig, timelock, or governance that can alter recorded entries, block registrations, or upgrade the logic.

## E.2 Trust the registry asks consumers to extend

- **Trust in EVM derivation correctness.** The contract's `CREATE` RLP encoding and `CREATE2` hashing must match EVM semantics. This is a code-review property of `_addressFrom` and the inline `CREATE2` computation; it is not a runtime assumption that can be violated by any party.
- **Trust in the off-chain trust list the consumer pairs with `deployerOf`.** The registry itself makes no claim about which deployers are reputable. Any downstream system that treats a recorded deployer as "approved" is importing trust from somewhere outside this repo.

## E.3 Failure modes that require off-chain coordination

- **Bad first registration is sticky.** If an attacker beats a legitimate deployer to the `registerAddress` call with *correct* inputs, the recorded deployer is still correct — but the `caller` field of the event will not match the deployer. Consumers reading the event log (rather than the `deployerOf` mapping) must not conflate `caller` with `deployer`.
- **Wrong inputs cannot capture a slot.** Mismatched inputs derive a different address (or revert on the code-present check), so they cannot squat the slot of a victim contract.
- **Derivation logic replacement.** If the derivation logic were ever proven wrong, the only fix is deploying a new registry contract and migrating consumers; the existing contract has no admin patch path.

---

## Section F — File:line references

| Invariant or rule | Source |
|---|---|
| `deployerOf` storage | `src/JBAddressRegistry.sol:40` |
| `registerAddress(deployer, nonce)` entrypoint | `src/JBAddressRegistry.sol:50-56` |
| `registerAddress(deployer, salt, bytecode)` entrypoint | `src/JBAddressRegistry.sol:66-73` |
| Zero-deployer guard | `src/JBAddressRegistry.sol:84` |
| Code-present-at-address guard | `src/JBAddressRegistry.sol:86` |
| First-write-only guard | `src/JBAddressRegistry.sol:88` |
| `deployerOf[addr] = deployer` write | `src/JBAddressRegistry.sol:90` |
| `AddressRegistered` emission | `src/JBAddressRegistry.sol:92` |
| Nonce > `uint64` revert | `src/JBAddressRegistry.sol:105` |
| RLP `CREATE` derivation branches | `src/JBAddressRegistry.sol:107-141` |
| `AddressRegistered` event | `src/interfaces/IJBAddressRegistry.sol:11` |
| `deployerOf` interface declaration | `src/interfaces/IJBAddressRegistry.sol:16` |
| `registerAddress(deployer, nonce)` interface | `src/interfaces/IJBAddressRegistry.sol:21` |
| `registerAddress(deployer, salt, bytecode)` interface | `src/interfaces/IJBAddressRegistry.sol:27` |

### Test coverage anchors

- Baseline registration behavior — `test/JBAddressRegistry.t.sol`
- Boundary conditions — `test/JBAddressRegistryEdge.t.sol`
- Live fork assumptions — `test/JBAddressRegistry_Fork.t.sol`
- Nonce width and truncation regressions — `test/regression/NonceTruncation.t.sol`
- Zero-deployer rejection — `test/regression/ZeroDeployerRegistration.t.sol`
- Unauthorized registrar / caller-identity irrelevance — `test/regression/RegressionUnauthorizedRegistrar.t.sol`
- Front-run and undeployed-code defenses — `test/regression/RegressionFrontRunRegistrationDoS.t.sol`
