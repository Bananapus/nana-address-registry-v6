# Juicebox Address Registry

Knowing who deployed a contract is the first step toward trusting it. This registry lets anyone prove a contract's deployer on-chain -- no access control and no admin keys.

`JBAddressRegistry` maps contract addresses to their deployers using deterministic address computation. Provide the deployer address and deployment parameters, and the registry verifies the relationship and stores it permanently. Frontend clients can then look up any registered contract to see who deployed it, which is especially useful for vetting Juicebox pay and cash-out hooks before interacting with them.

## Deployed Address

`JBAddressRegistry` is deployed at the same address on all supported networks via deterministic `create2` deployment:

```
0x2d9b78cb37ca724cfb9b32cd8e9a5dc1c88bc7bb
```

| Network | Chain ID |
|---------|----------|
| Ethereum | 1 |
| Optimism | 10 |
| Arbitrum | 42161 |
| Base | 8453 |
| Ethereum Sepolia | 11155111 |
| Optimism Sepolia | 11155420 |
| Arbitrum Sepolia | 421614 |
| Base Sepolia | 84532 |

## Architecture

| Contract | Description |
|----------|-------------|
| `JBAddressRegistry` | Standalone registry. Computes deployed addresses deterministically from deployer parameters and stores the deployer in `deployerOf`. No constructor arguments, no access control, no external dependencies. |

### Interface

| Type | Description |
|------|-------------|
| `IJBAddressRegistry` | Interface exposing `deployerOf`, both `registerAddress` overloads, and the `AddressRegistered` event. |

### How It Works

Anyone can register a contract by providing its deployer and deployment parameters:

- **`create` deployments**: Provide the deployer address and the nonce at the time of deployment. The registry reconstructs the address using RLP encoding (the same encoding the EVM uses internally to compute `create` addresses).
- **`create2` deployments**: Provide the deployer address, the `create2` salt, and the full deployment bytecode (creation code + encoded constructor arguments). The registry computes `keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))`.

In both cases, the registry stores the mapping `deployerOf[computedAddress] = deployer` and emits an `AddressRegistered` event. Frontend clients can then look up any contract's deployer to verify trust.

No access control is needed -- only the correct deployer + parameters can produce a given address, so registrations cannot be faked.

### Events

| Event | Fields | Emitted When |
|-------|--------|-------------|
| `AddressRegistered` | `address indexed addr`, `address indexed deployer`, `address caller` | A contract address is registered via either `registerAddress` overload. `caller` is `msg.sender`, which may differ from the deployer. |

### Risks

Hooks have token minting access, making malicious hooks dangerous. A registered deployer does not guarantee a hook is safe -- it only tells you who deployed it. Clients should warn project owners and users about any potential for unintended or adversarial behavior, especially for unknown hooks.

Deployers can be exploited or act maliciously. Clients should still communicate risk to users even when the deployer is a known entity.

### Limitations

- The `_addressFrom` function for `create` addresses uses RLP encoding that only supports nonces up to `uint64` max (18,446,744,073,709,551,615). Higher nonces revert with `JBAddressRegistry_NonceTooLarge`. In practice, this limit is unreachable.
- No overwrite protection: registering the same computed address again overwrites the previous deployer. This is safe because only the correct deployer + parameters produce a given address -- a second call with the same inputs just re-registers the same deployer.
- Registration is permissionless -- anyone can call `registerAddress`, not just the deployer. Security relies entirely on deterministic address computation.

## Deployment

The deploy script uses [Sphinx](https://github.com/sphinx-labs/sphinx) for deterministic multi-chain deployment. The registry is deployed via `create2` with the salt `_JBAddressRegistryV6_`, ensuring the same address on every chain. The script skips deployment if the bytecode is already present at the computed address.

A helper library `AddressRegistryDeploymentLib` is provided in `script/helpers/` to resolve deployed addresses from Sphinx deployment artifacts at runtime.

## Install

```bash
npm install
```

## Develop

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts |
| `forge test` | Run unit tests |
| `FOUNDRY_PROFILE=CI forge test` | Run fork tests (requires `RPC_ETHEREUM_MAINNET` env var) |
| `forge coverage --match-path "./src/*.sol" --report lcov --report summary` | Generate coverage report |
| `npm run deploy:mainnets` | Propose mainnet deployment via Sphinx |
| `npm run deploy:testnets` | Propose testnet deployment via Sphinx |
