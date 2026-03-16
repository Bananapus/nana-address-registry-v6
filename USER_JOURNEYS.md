# User Journeys -- nana-address-registry-v6

Concrete end-to-end flows through the address registry. Each journey traces the exact function calls, state changes, and external interactions.

## Journey 1: Register a Contract Deployed via create

**Actor:** Anyone (the deployer, the deployed contract itself, or a third party).
**Goal:** Record the deployer of a contract that was deployed using the `create` opcode (standard deployment).

### Precondition

A contract exists on-chain at the address that `create` would produce from `(deployer, nonce)`. The caller knows the deployer's address and the nonce used during deployment.

### Steps

1. **Caller invokes `registerAddress(address deployer, uint256 nonce)`**

   - The `nonce` must be `<= type(uint64).max` or the call reverts with `JBAddressRegistry_NonceTooLarge(nonce)`
   - The contract calls `_addressFrom(deployer, nonce)` internally

2. **`_addressFrom` computes the create address via RLP encoding**

   - Selects the correct RLP encoding branch based on the nonce range (10 branches: `0`, `1-0x7f`, `0x80-0xff`, ..., up to `uint64` max)
   - Builds the RLP-encoded byte sequence: `[list_prefix, 0x94, deployer_20_bytes, nonce_encoding]`
   - Hashes the sequence with `keccak256`
   - Extracts the low 160 bits as the computed address via inline assembly

3. **`_registerAddress` stores the mapping and emits the event**

   - Sets `deployerOf[computedAddress] = deployer`
   - Emits `AddressRegistered(addr: computedAddress, deployer: deployer, caller: msg.sender)`

### Result

`deployerOf[computedAddress]` now returns `deployer`. Anyone querying the registry for that address can verify who deployed it.

### What to verify

- The computed address matches the actual on-chain contract address for the given `(deployer, nonce)` pair.
- If the caller provides incorrect parameters (wrong nonce, wrong deployer), a mapping is still created -- but for a different (likely nonexistent) address. The registry does not verify that code exists at the computed address.
- Calling `registerAddress` again with the same parameters is idempotent (same result, no revert).
- The `caller` in the event is `msg.sender`, which may differ from `deployer`.

---

## Journey 2: Register a Contract Deployed via create2

**Actor:** Anyone (the deployer, the deployed contract itself, or a third party).
**Goal:** Record the deployer of a contract that was deployed using the `create2` opcode (deterministic deployment).

### Precondition

A contract exists on-chain at the address that `create2` would produce from `(deployer, salt, bytecode)`. The caller knows the deployer's address, the salt, and the full creation bytecode (including constructor arguments).

### Steps

1. **Caller invokes `registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)`**

   - No parameter validation beyond the address computation itself
   - `bytecode` must include ABI-encoded constructor arguments appended to the creation code

2. **The contract computes the create2 address inline**

   - `address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))))`
   - This matches the EIP-1014 specification

3. **`_registerAddress` stores the mapping and emits the event**

   - Sets `deployerOf[computedAddress] = deployer`
   - Emits `AddressRegistered(addr: computedAddress, deployer: deployer, caller: msg.sender)`

### Result

`deployerOf[computedAddress]` now returns `deployer`. Frontends and other contracts can look up the deployer of any `create2`-deployed contract.

### What to verify

- The `bytecode` parameter must be the full creation bytecode, not the deployed (runtime) bytecode. Omitting constructor arguments produces a different hash and therefore a different address.
- For large bytecode payloads, `keccak256(bytecode)` is computed in memory. The gas cost scales with bytecode size, but the registry itself has no gas limit issues -- the caller pays.
- The salt is deployer-specific. Different deployers with the same salt and bytecode produce different addresses (because the deployer address is part of the hash input).

---

## Journey 3: Frontend Verifies a Hook's Deployer

**Actor:** Frontend application or off-chain service.
**Goal:** Determine whether a Juicebox hook was deployed by a trusted factory.

### Precondition

The hook contract has been registered in the registry (via Journey 1 or 2). The frontend maintains a list of trusted deployer addresses.

### Steps

1. **Frontend reads `deployerOf(hookAddress)`**

   - This is a simple public mapping getter -- a `staticcall` with no state changes
   - Returns `address(0)` if the hook has never been registered

2. **Frontend evaluates the result**

   - If `deployer == address(0)`: the hook is unregistered. The frontend should treat it as untrusted.
   - If `deployer` is in the trusted deployer set: the hook was deployed by a known, audited factory. The frontend can display it with confidence.
   - If `deployer` is a non-zero address not in the trusted set: the hook is registered but was deployed by an unknown deployer. The frontend should flag it as unverified.

### Result

The frontend can make a trust decision about the hook without needing to trace the deployment transaction on-chain.

### What to verify

- `deployerOf` returns `address(0)` for any address that has never been registered. There is no way to distinguish "never registered" from "registered with `deployer = address(0)`", though the latter requires deliberately passing `address(0)` as the deployer.
- The registry provides no guarantee that code exists at the registered address. A deployer could register an address for a contract that has been self-destructed or was never deployed.
- The registry provides no guarantee that the registered deployer is the *actual* deployer. It only guarantees that the deterministic computation of `(deployer, nonce)` or `(deployer, salt, bytecode)` produces that address. Since the EVM's address derivation is deterministic, this is equivalent -- but the registry itself does not verify the deployment transaction.

---

## Journey 4: Overwrite a Previous Registration

**Actor:** Anyone.
**Goal:** Re-register an address with the same or different parameters.

### Precondition

`deployerOf[addr]` already has a non-zero value from a previous registration.

### Steps

1. **Caller invokes either `registerAddress` overload with parameters that compute to `addr`**

2. **`_registerAddress` overwrites the existing value**

   - `deployerOf[addr] = deployer` (unconditional write, no check for existing value)
   - Emits a new `AddressRegistered` event

### Result

The previous deployer mapping is overwritten. The event log contains both the old and new registrations.

### What to verify

- Overwriting is safe because the same address can only be computed from the same `(deployer, nonce)` or `(deployer, salt, bytecode)` parameters (assuming no keccak256 collision). Re-registering with the same parameters produces the same result.
- There is no way to "unregister" an address. Setting `deployerOf[addr] = address(0)` would require computing a `(deployer, nonce)` pair that produces `addr` with `deployer = address(0)`, which is theoretically possible but practically useless.
- The event log preserves the full history of registrations. Off-chain indexers can detect overwrites by tracking multiple `AddressRegistered` events for the same `addr`.
