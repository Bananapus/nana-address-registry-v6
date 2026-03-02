# nana-address-registry-v5 — AI Reference

## Purpose

Allows anyone to register the deployer of a contract so that frontend clients can verify trust. Intended primarily for Juicebox pay/cash-out hooks, but works for any contract deployed via `create` or `create2`.

## Contracts

### JBAddressRegistry (src/JBAddressRegistry.sol)
Single stateful contract. No constructor arguments, no access control, no dependencies.

**Storage:**
- `mapping(address addr => address deployer) public deployerOf`

**Events:**
- `AddressRegistered(address indexed addr, address indexed deployer, address caller)`

## Entry Points

### Register via create (nonce-based)
```solidity
function registerAddress(address deployer, uint256 nonce) external
```
Computes the deployed address using RLP encoding of `(deployer, nonce)`. Nonce must be <= 2^32.

### Register via create2 (salt+bytecode)
```solidity
function registerAddress(address deployer, bytes32 salt, bytes calldata bytecode) external
```
Computes `address(keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode)))`.

### Query
```solidity
function deployerOf(address addr) external view returns (address deployer)
```

## Integration Points

- **Frontend clients**: Query `deployerOf(hookAddress)` to check if a hook was deployed by a trusted deployer.
- **Hook deployers**: Call `registerAddress` after deploying a hook to make it verifiable.
- **No protocol dependencies**: This contract is standalone -- it does not import or interact with any other Juicebox contracts at runtime.

## Key Patterns

- **Permissionless registration**: Anyone can register any address. The security comes from deterministic address computation -- you cannot fake a deployer because the computed address would not match.
- **Nonce limit**: The `_addressFrom` function supports nonces up to `2^32` using RLP encoding with variable-length nonce encoding (0x80 for nonce 0, single byte for 1-127, length-prefixed for larger).
- **No overwrite protection**: Calling `registerAddress` with different parameters for the same computed address will overwrite the deployer. This is safe because only the correct deployer+nonce/salt can produce a given address.
