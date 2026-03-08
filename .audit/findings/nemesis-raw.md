# Nemesis Audit — Raw Findings (Pre-Verification)

## Scope
- Language: Solidity 0.8.26
- Modules analyzed: JBAddressRegistry, IJBAddressRegistry, Deploy.s.sol, AddressRegistryDeploymentLib
- Functions analyzed: 5 (2 external, 2 internal, 1 public view)
- Coupled state pairs mapped: 0 (single-variable design)
- Mutation paths traced: 2 (CREATE registration, CREATE2 registration)
- Nemesis loop iterations: 2 (converged at Pass 2)

## Function-State Matrix

| Function | Reads | Writes | Guards | Internal Calls | External Calls |
|----------|-------|--------|--------|----------------|----------------|
| registerAddress(deployer, nonce) | — | deployerOf[addr] | NONE | _addressFrom, _registerAddress | NONE |
| registerAddress(deployer, salt, bytecode) | — | deployerOf[addr] | NONE | _registerAddress | NONE |
| _addressFrom(origin, nonce) | — | — | N/A (pure) | — | NONE |
| _registerAddress(addr, deployer) | — | deployerOf[addr] | N/A (internal) | — | NONE |
| deployerOf(addr) | deployerOf | — | NONE | — | NONE |

## Coupled State Dependency Map

**NO COUPLED PAIRS.** Single storage variable (`deployerOf` mapping). State inconsistency bugs are structurally impossible.

## Raw Findings

### NM-001 (Raw): Silent nonce truncation in _addressFrom for nonces > uint32
- **Source:** Feynman Pass 1, Category 4 (Assumptions) + Category 5 (Boundaries)
- **Severity (raw):** LOW
- **Location:** `src/JBAddressRegistry.sol:78-79`
- **Description:** `_addressFrom` accepts `uint256 nonce` but casts to `uint32(nonce)` in the else branch. Nonces > 2^32-1 are silently truncated, computing wrong addresses.
- **Needs verification:** Confirm with PoC.

### NM-002 (Raw): Deploy script deployer address mismatch
- **Source:** Feynman Pass 1, Category 3 (Consistency)
- **Severity (raw):** LOW
- **Location:** `script/Deploy.s.sol:31`
- **Description:** `_isDeployed` hardcodes Arachnid proxy as deployer. If Sphinx doesn't route through it, the check is wrong.
- **Needs verification:** Confirm Sphinx uses Arachnid proxy.

### NM-003 (Raw): Project name mismatch in deployment helper
- **Source:** Feynman Pass 1, Category 3 (Consistency)
- **Severity (raw):** LOW
- **Location:** `script/helpers/AddressRegistryDeploymentLib.sol:46`
- **Description:** Uses "nana-address-registry" but Deploy.s.sol uses "nana-address-registry-v6".
- **Needs verification:** Check actual directory structure.
