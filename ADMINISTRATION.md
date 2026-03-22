# Administration

Admin privileges and their scope in nana-address-registry-v6.

## Roles

None. `JBAddressRegistry` has no owner, no admin, and no access control. The contract does not inherit from `Ownable`, `AccessControl`, or any permissioned pattern.

## Privileged Functions

### JBAddressRegistry

| Function | Required Role | Permission ID | Scope | What It Does |
|----------|--------------|---------------|-------|--------------|
| `registerAddress(address deployer, uint256 nonce)` | None | N/A | Global | Computes a `create` address from deployer + nonce and stores the deployer mapping |
| `registerAddress(address deployer, bytes32 salt, bytes bytecode)` | None | N/A | Global | Computes a `create2` address from deployer + salt + bytecode and stores the deployer mapping |
| `deployerOf(address)` | None | N/A | Global | View function — returns the registered deployer for a given address |

Every function is callable by any address. There are no restricted operations.

## Registration Model

- **Fully permissionless.** Any address can register any deployer/nonce or deployer/salt/bytecode combination.
- **No caller verification.** The registry does not check whether `msg.sender` is the deployer. It only verifies that the computed address is valid by storing the mapping.
- **Overwritable.** A second registration for the same computed address overwrites the previous deployer mapping. Last writer wins.
- **Permanent storage, no removal.** There is no `unregister` or `removeAddress` function. Entries can be overwritten but never deleted.
- **No approval or queue.** Registrations take effect immediately in the same transaction.

## Client-Side Trust

The registry stores deployer mappings without making trust judgments. All trust decisions are delegated to clients:

- **No on-chain filtering.** There is no event or view function that distinguishes "trusted" from "untrusted" deployers. Clients must maintain their own allowlist of known deployer addresses and cross-reference against `deployerOf()`.
- **No event-based discovery.** The contract emits no events. Clients that need to discover new registrations must poll storage or monitor transaction traces.
- **Overwrite risk.** Since registrations are overwritable, a client that caches `deployerOf(addr)` at time T may see a different result at time T+1 if someone re-registers the same address with a different deployer/nonce or deployer/salt/bytecode combination. Clients should re-check at time of use rather than caching indefinitely.
- **No validation of deployment.** The registry computes the expected address from the inputs but does not verify that a contract actually exists at that address. A registration can be created for an address that has not yet been deployed (or will never be deployed).

## Admin Boundaries

There are no admins. Specifically:

- **No pause mechanism.** The registry cannot be paused or frozen.
- **No upgrade path.** The contract is not proxied or upgradeable.
- **No fee extraction.** The contract holds no funds and collects no fees.
- **No blocklist.** No address can be prevented from registering.
- **No migration.** There is no way to transfer state to a new registry contract.

The only trust assumption is on the frontend side: clients must maintain their own list of trusted deployers and use `deployerOf()` to check whether a contract was deployed by one of them. The registry itself makes no trust judgments.
