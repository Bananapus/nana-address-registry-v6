# User Journeys -- nana-address-registry-v6

All user paths through the Juicebox V6 address registry. For each journey: entry point, key parameters, state changes, events, and edge cases.

---

## 1. Register a Contract Deployed via `create`

**Entry point**: `JBAddressRegistry.registerAddress(address deployer, uint256 nonce)`

**Who can call**: Anyone. No access control -- any account can register any `(deployer, nonce)` pair. The caller does not need to be the deployer.

**Parameters**:
- `deployer` -- Address of the account that deployed the contract via `create`
- `nonce` -- The nonce the deployer's account had when deploying the contract (must be `<= type(uint64).max`)

**State changes**:
1. Computes the deterministic `create` address via RLP encoding of `[deployer, nonce]` -- selects one of 10 encoding branches based on nonce range (`0`, `1..0x7f`, `0x80..0xff`, ..., up to `uint64` max)
2. `JBAddressRegistry.deployerOf[computedAddress] = deployer` -- stores the deployer mapping

**Events**: `AddressRegistered(addr, deployer, caller)` -- where `addr` is the computed `create` address, `deployer` is the registered deployer, and `caller` is `msg.sender`. Both `addr` and `deployer` are `indexed`.

**Edge cases**:
- `nonce > type(uint64).max` reverts with `JBAddressRegistry_NonceTooLarge(nonce)`
- If the caller provides incorrect parameters (wrong nonce, wrong deployer), a mapping is still created -- but for a different (likely nonexistent) address. The registry does not verify that code exists at the computed address.
- Calling `registerAddress` again with the same parameters is idempotent (same mapping value, same event, no revert).
- The `caller` in the event is `msg.sender`, which may differ from `deployer`.

---

## 2. Register a Contract Deployed via `create2`

**Entry point**: `JBAddressRegistry.registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)`

**Who can call**: Anyone. No access control -- any account can register any `(deployer, salt, bytecode)` tuple. The caller does not need to be the deployer.

**Parameters**:
- `deployer` -- Address of the account or factory contract that deployed the contract via `create2`
- `salt` -- The `create2` salt used during deployment
- `bytecode` -- The full creation bytecode including ABI-encoded constructor arguments (not runtime bytecode)

**State changes**:
1. Computes the deterministic `create2` address: `address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))))`
2. `JBAddressRegistry.deployerOf[computedAddress] = deployer` -- stores the deployer mapping

**Events**: `AddressRegistered(addr, deployer, caller)` -- where `addr` is the computed `create2` address, `deployer` is the registered deployer, and `caller` is `msg.sender`. Both `addr` and `deployer` are `indexed`.

**Edge cases**:
- The `bytecode` parameter must be the full creation bytecode, not the deployed (runtime) bytecode. Omitting constructor arguments produces a different hash and therefore a different address.
- For large bytecode payloads, `keccak256(bytecode)` is computed in memory. Gas cost scales with bytecode size, but the registry itself has no gas limit issues -- the caller pays.
- The salt is deployer-specific. Different deployers with the same salt and bytecode produce different addresses (because the deployer address is part of the hash input).
- No parameter validation beyond the address computation itself. No revert conditions exist for this overload.

---

## 3. Frontend Verifies a Hook's Deployer

**Entry point**: `JBAddressRegistry.deployerOf(address addr)` (public mapping getter -- `view`)

**Who can call**: Anyone. This is a `view` function (auto-generated mapping getter) with no access control or state changes.

**Parameters**:
- `addr` -- The address of the contract to look up

**State changes**: None. Read-only query.

**Events**: None. No state mutation occurs.

**Result**: Returns the registered deployer address, or `address(0)` if the address has never been registered. The frontend evaluates:
- `deployer == address(0)` -- the hook is unregistered; treat as untrusted
- `deployer` is in the trusted deployer set -- the hook was deployed by a known, audited factory; display with confidence
- `deployer` is a non-zero address not in the trusted set -- registered but deployed by an unknown deployer; flag as unverified

**Edge cases**:
- `deployerOf` returns `address(0)` for any address never registered. There is no way to distinguish "never registered" from "registered with `deployer = address(0)`", though the latter requires deliberately passing `address(0)` as the deployer.
- The registry provides no guarantee that code exists at the registered address. A deployer could register an address for a contract that has been self-destructed or was never deployed.
- The registry provides no guarantee that the registered deployer is the *actual* deployer. It only guarantees that the deterministic computation of `(deployer, nonce)` or `(deployer, salt, bytecode)` produces that address. Since the EVM's address derivation is deterministic, this is equivalent -- but the registry itself does not verify the deployment transaction.

---

## 4. Overwrite a Previous Registration

**Entry point**: `JBAddressRegistry.registerAddress(address deployer, uint256 nonce)` or `JBAddressRegistry.registerAddress(address deployer, bytes32 salt, bytes calldata bytecode)`

**Who can call**: Anyone. There is no access control on overwrites. No owner check or deployer verification is performed.

**Parameters**: Same as Journey 1 or Journey 2, depending on which `registerAddress` overload is called. The provided parameters must compute to the same target address as the previous registration.

**State changes**:
1. `JBAddressRegistry.deployerOf[addr] = deployer` -- unconditional `SSTORE`, overwrites any existing value without checking the previous deployer

**Events**: `AddressRegistered(addr, deployer, caller)` -- emitted on every call, even if the stored value is unchanged.

**Edge cases**:
- Overwriting is safe because the same address can only be computed from the same `(deployer, nonce)` or `(deployer, salt, bytecode)` parameters (assuming no keccak256 collision). Re-registering with the same parameters produces the same result.
- There is no way to "unregister" an address. Setting `deployerOf[addr] = address(0)` would require computing a `(deployer, nonce)` pair that produces `addr` with `deployer = address(0)`, which is theoretically possible but practically useless.
- The event log preserves the full history of registrations. Off-chain indexers can detect overwrites by tracking multiple `AddressRegistered` events for the same `addr`.
