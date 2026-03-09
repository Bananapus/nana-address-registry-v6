# nana-address-registry-v6 — Architecture

## Purpose

Deployer verification registry for Juicebox V6. Allows contracts deployed via `create` or `create2` to publicly register their deployer's address. Frontend clients use this to verify that hooks and other contracts were deployed by trusted deployers.

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

## Dependencies

- `@sphinx-labs/plugins` — Deployment tooling (devDependency only)

No runtime Solidity dependencies — this is a standalone contract.
