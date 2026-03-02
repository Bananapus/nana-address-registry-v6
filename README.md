# nana-address-registry-v5

Registry that maps contract addresses to their deployers for frontend trust verification. Supports both `create` (nonce-based) and `create2` (salt+bytecode) deployment verification.

## Architecture

| Contract | Description |
|---|---|
| `src/JBAddressRegistry.sol` | Main registry. Computes deployed addresses deterministically and stores their deployers. |
| `src/interfaces/IJBAddressRegistry.sol` | Interface. |

### How It Works

Anyone can register a contract by providing its deployer and deployment parameters. The registry computes the expected address from these parameters and stores the deployer in `deployerOf[computedAddress]`. Frontend clients can then look up any contract's deployer to decide whether to trust it.

## Install

```bash
npm install @bananapus/address-registry
```

Or with Forge:

```bash
forge install Bananapus/nana-address-registry
```

## Develop

```bash
npm ci && forge install
forge build
forge test
```
