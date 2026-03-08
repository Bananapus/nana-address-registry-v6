# N E M E S I S — Verified Findings

## Scope
- Language: Solidity 0.8.26
- Modules analyzed: JBAddressRegistry, IJBAddressRegistry, Deploy.s.sol, AddressRegistryDeploymentLib
- Functions analyzed: 5 (2 external, 2 internal, 1 public view)
- Coupled state pairs mapped: 0 (single-variable design)
- Mutation paths traced: 2 (CREATE registration, CREATE2 registration)
- Nemesis loop iterations: 2 (converged at Pass 2 — no coupled state to iterate on)

## Nemesis Map (Phase 1 Cross-Reference)

Single storage variable (`deployerOf` mapping). No coupled pairs exist. The Nemesis cross-reference collapses to the Function-State Matrix:

| Function | Writes | Guards | Internal Calls |
|----------|--------|--------|----------------|
| registerAddress(deployer, nonce) | deployerOf[addr] | NONE | _addressFrom, _registerAddress |
| registerAddress(deployer, salt, bytecode) | deployerOf[addr] | NONE | _registerAddress |
| _registerAddress(addr, deployer) | deployerOf[addr] | N/A | — |

## Verification Summary

| ID | Source | Coupled Pair | Breaking Op | Severity | Verdict |
|----|--------|-------------|-------------|----------|---------|
| NM-001 | Feynman P1 | N/A | _addressFrom() | LOW | TRUE POS |
| NM-002 | Feynman P1 | N/A | _isDeployed() | LOW | FALSE POS |
| NM-003 | Feynman P1 | N/A | getDeployment() | LOW | FALSE POS |

## Verified Findings (TRUE POSITIVES only)

### Finding NM-001: Silent nonce truncation for nonces > uint32
**Severity:** LOW
**Source:** Feynman Pass 1 (Category 4: Assumptions, Category 5: Boundaries)
**Verification:** Hybrid — code trace confirmed mechanism + existing PoC test passes

**Feynman Question that exposed it:**
> Q4.6: "What does this function assume about INPUT AMOUNTS? What if nonce exceeds uint32?"
> Q1.4: "Is the catch-all else branch SUFFICIENT for all remaining nonce values?"

**The code:**
```solidity
// src/JBAddressRegistry.sol:66-86
function _addressFrom(address origin, uint256 nonce) internal pure returns (address addr) {
    bytes memory data;
    if (nonce == 0x00) {
        // ... correct for nonce 0
    } else if (nonce <= 0x7f) {
        // ... correct for 1-byte nonce
    } else if (nonce <= 0xff) {
        // ... correct for 2-byte nonce
    } else if (nonce <= 0xffff) {
        // ... correct for 3-byte nonce
    } else if (nonce <= 0xffffff) {
        // ... correct for 4-byte nonce
    } else {
        // BUG: uint32(nonce) silently truncates nonces > 2^32-1
        data = abi.encodePacked(bytes1(0xda), bytes1(0x94), origin, bytes1(0x84), uint32(nonce));
    }
    // ...
}
```

**Why this is wrong:**
The function parameter accepts `uint256` but the catch-all `else` branch casts to `uint32(nonce)`, silently truncating nonces above 2^32-1. For example, `_addressFrom(deployer, 0x100000000)` computes the same address as `_addressFrom(deployer, 0)` because `uint32(0x100000000) == 0`. The function silently returns a wrong address instead of reverting.

The comment at L62-63 documents this as a known limitation: *"this won't work for nonces > 2**32."* However, the function does not enforce this — it silently computes a wrong address.

**Verification evidence:**
- Existing test `test_nonceAboveUint32_producesWrongAddress` in `JBAddressRegistryEdge.t.sol:237-273` confirms the truncation behavior.
- Test passes: nonce `0x100000000` maps to the same address as nonce `0`.

**Attack scenario:**
1. TrustedDeployer deploys contract A at nonce 0 (address X).
2. TrustedDeployer reaches nonce 2^32 (requires ~4.3 billion transactions — practically impossible).
3. Someone calls `registerAddress(trustedDeployer, 2^32)`.
4. Function computes `_addressFrom(trustedDeployer, 0)` due to truncation = address X.
5. `deployerOf[X] = trustedDeployer` — registers the nonce-0 address, not the nonce-2^32 address.

**Impact:**
Extremely low practical impact. No known Ethereum address has reached nonce 2^32. The limitation is documented. The registry maps a wrong address — the deployer value itself is correct, but it's associated with the wrong deployed contract.

**Suggested fix:**
```solidity
function _addressFrom(address origin, uint256 nonce) internal pure returns (address addr) {
    // Add explicit revert for unsupported nonces
    require(nonce <= type(uint32).max, "Nonce exceeds uint32");
    // ... rest unchanged
}
```

---

## Feedback Loop Discoveries

No feedback loop discoveries. The contract has no coupled state pairs, so the State Inconsistency Auditor produced zero findings. The iterative loop converged immediately at Pass 2 with no cross-feed findings.

## False Positives Eliminated

### NM-002: Deploy script deployer mismatch — FALSE POSITIVE
**Original claim:** `_isDeployed` in Deploy.s.sol hardcodes the Arachnid proxy address, but the `new ... {salt: ...}()` deployment might use a different deployer.
**Why false:** Sphinx explicitly uses the Arachnid deterministic-deployment-proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`) for all CREATE2 deployments. This is confirmed in `SphinxUtils.sol` which validates that the proxy is used during deployment. The `_isDeployed` check is correct.

### NM-003: Project name mismatch in deployment helper — FALSE POSITIVE
**Original claim:** `AddressRegistryDeploymentLib` uses `"nana-address-registry"` but `Deploy.s.sol` configures `sphinxConfig.projectName = "nana-address-registry-v6"`.
**Why false:** The deployment artifacts directory is `deployments/nana-address-registry/` (verified on disk), not `deployments/nana-address-registry-v6/`. The Sphinx project name and the artifact directory name are intentionally different. The library correctly references the artifact directory path.

## Downgraded Findings

None. NM-001 was assessed as LOW from the start and remains LOW after verification.

## Summary
- Total functions analyzed: 5
- Coupled state pairs mapped: 0
- Nemesis loop iterations: 2 (converged — no coupled state)
- Raw findings (pre-verification): 0 C | 0 H | 0 M | 3 L
- Feedback loop discoveries: 0 (no coupled state to cross-feed)
- After verification: 1 TRUE POSITIVE | 2 FALSE POSITIVE | 0 DOWNGRADED
- **Final: 0 CRITICAL | 0 HIGH | 0 MEDIUM | 1 LOW**
