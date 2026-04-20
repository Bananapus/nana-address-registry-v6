# Address Registry Runtime

## Core Role

- [`src/JBAddressRegistry.sol`](../src/JBAddressRegistry.sol) reconstructs deployment addresses from `create` or `create2` inputs and binds a deployer to that computed address once.

## High-Risk Areas

- First-write semantics: bad initial registration can become sticky.
- Provenance scope: this repo proves deployer identity, not code safety or allowlist status.
- Input correctness: wrong nonce, salt, or bytecode assumptions produce wrong addresses.

## Tests To Trust First

- [`test/JBAddressRegistry.t.sol`](../test/JBAddressRegistry.t.sol) for baseline behavior.
- [`test/JBAddressRegistryEdge.t.sol`](../test/JBAddressRegistryEdge.t.sol) for boundary conditions.
- [`test/JBAddressRegistry_Fork.t.sol`](../test/JBAddressRegistry_Fork.t.sol) for live assumptions.
- [`test/regression/NonceTruncation.t.sol`](../test/regression/NonceTruncation.t.sol) for nonce-width and reconstruction regressions.
- [`test/audit/ZeroDeployerRegistration.t.sol`](../test/audit/ZeroDeployerRegistration.t.sol), [`test/audit/CodexUnauthorizedRegistrar.t.sol`](../test/audit/CodexUnauthorizedRegistrar.t.sol), and [`test/audit/CodexFrontRunRegistrationDoS.t.sol`](../test/audit/CodexFrontRunRegistrationDoS.t.sol) for the abuse cases this repo is expected to resist.
