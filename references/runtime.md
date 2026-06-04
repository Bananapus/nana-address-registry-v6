# Address Registry Runtime

## Core role

- [`src/JBAddressRegistry.sol`](../src/JBAddressRegistry.sol) reconstructs deployment addresses from `create` or `create2` inputs and binds a deployer to that computed address once.

## High-risk areas

- First-write semantics: bad initial registration can become sticky.
- Provenance scope: this repo proves deployer identity, not code safety or allowlist status.
- Input correctness: wrong nonce, salt, or bytecode assumptions produce wrong addresses.

## Tests to trust first

- [`test/JBAddressRegistry.t.sol`](../test/JBAddressRegistry.t.sol) for baseline behavior.
- [`test/JBAddressRegistryEdge.t.sol`](../test/JBAddressRegistryEdge.t.sol) for boundary conditions.
- [`test/JBAddressRegistry_Fork.t.sol`](../test/JBAddressRegistry_Fork.t.sol) for live assumptions.
- [`test/regression/NonceTruncation.t.sol`](../test/regression/NonceTruncation.t.sol) for nonce-width and reconstruction regressions.
- [`test/regression/ZeroDeployerRegistration.t.sol`](../test/regression/ZeroDeployerRegistration.t.sol), [`test/regression/RegressionUnauthorizedRegistrar.t.sol`](../test/regression/RegressionUnauthorizedRegistrar.t.sol), and [`test/regression/RegressionFrontRunRegistrationDoS.t.sol`](../test/regression/RegressionFrontRunRegistrationDoS.t.sol) for the abuse cases this repo is expected to resist.
