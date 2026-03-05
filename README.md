# nana-address-registry-v5

Registry that maps contract addresses to their deployers for frontend trust verification. Supports both `create` (nonce-based) and `create2` (salt+bytecode) deployment verification.

## Architecture

| Contract | Description |
|----------|-------------|
| `JBAddressRegistry` | Standalone registry. Computes deployed addresses deterministically from deployer parameters and stores the deployer in `deployerOf`. |

### Supporting Types

| Type | Description |
|------|-------------|
| `IJBAddressRegistry` | Interface exposing `deployerOf`, and both `registerAddress` overloads. |

### How It Works

Anyone can register a contract by providing its deployer and deployment parameters (`nonce` for `create`, or `salt` + `bytecode` for `create2`). The registry computes the expected address from these parameters and stores the deployer in `deployerOf[computedAddress]`. Frontend clients can then look up any contract's deployer to verify trust.

No access control is needed -- only the correct deployer+parameters can produce a given address, so registrations cannot be faked.

### Risks

Hooks have token minting access, making malicious hooks dangerous. Clients should warn project owners and users about any potential for unintended or adversarial behavior, especially for unknown hooks.

Deployers can be exploited. Clients should still communicate risk to users even when the deployer is registered.

## Install

```bash
npm install
```

## Develop

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts |
| `forge test` | Run unit tests |
| `FOUNDRY_PROFILE=CI forge test` | Run fork tests |
| `forge coverage --match-path "./src/*.sol" --report lcov --report summary` | Generate coverage report |
| `npm run deploy:mainnets` | Propose mainnet deployment via Sphinx |
| `npm run deploy:testnets` | Propose testnet deployment via Sphinx |
