# nana-address-registry-v6 — Architecture

## Purpose

Juicebox projects can attach arbitrary hook contracts (pay hooks, cashout hooks, 721 tier hooks, etc.) that execute during payments, cashouts, and payouts. A malicious hook could steal funds or mislead users. Frontends need a way to answer the question: "Was this hook deployed by a trusted deployer like `JB721TiersHookDeployer`?"

`JBAddressRegistry` solves this by letting contracts deployed via `create` or `create2` publicly register their deployer's address. A frontend can then call `deployerOf(hookAddress)` and check the result against its own list of trusted deployers — displaying warnings or blocking interactions for hooks with unknown origins.

## Contract Map

```
src/
├── JBAddressRegistry.sol     — Registry: registerAddress (create/create2), deployerOf mapping
└── interfaces/
    └── IJBAddressRegistry.sol — Interface
```

## Key Operations

### Registration (create)
```
Deployer → JBAddressRegistry.registerAddress(deployer, nonce)
  → Compute address via RLP encoding of [deployer, nonce]
  → Store deployerOf[computedAddress] = deployer
  → Emit AddressRegistered
```

### Registration (create2)
```
Deployer → JBAddressRegistry.registerAddress(deployer, salt, bytecode)
  → Compute address via keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))
  → Store deployerOf[computedAddress] = deployer
  → Emit AddressRegistered
```

### Verification
```
Frontend → JBAddressRegistry.deployerOf(hookAddress)
  → Returns deployer address (or address(0) if unregistered)
  → Frontend checks deployer against trusted deployer list
```

## Design Decisions

**Deployer verification, not a whitelist.** The registry records *who* deployed a contract, not *whether* a contract is approved. This keeps the registry permissionless and neutral — any deployer can register, and trust decisions are made by each frontend independently. There is no governance or admin role.

**Both `create` and `create2` support.** Deployers that use `create` (nonce-based) and `create2` (salt + bytecode) both exist in the Juicebox ecosystem. Supporting both ensures any deployer can register its contracts regardless of deployment strategy.

**No validation beyond hash match.** The registry does not check that registered addresses contain code, implement a particular interface, or were recently deployed. It only verifies that the provided deployer + nonce/salt/bytecode deterministically produce the claimed address. This keeps the contract simple and gas-efficient — frontends already perform their own trust checks on the deployer address.

**Anyone can call `registerAddress`.** Registration is not restricted to the deployer itself. Any account that knows the deployer address and nonce (or salt + bytecode) can register a contract. This is safe because the mapping is deterministic — providing incorrect inputs simply computes a different address, not a false registration for the target contract.

## Dependencies

- `@sphinx-labs/plugins` — Deployment tooling (devDependency only)

No runtime Solidity dependencies — this is a standalone contract.
