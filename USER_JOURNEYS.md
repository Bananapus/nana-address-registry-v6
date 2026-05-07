# User Journeys

## Repo Purpose

This repo records deployer provenance for contracts whose address can be reconstructed from `create` or `create2` inputs. It does not say whether a deployment is safe, canonical, or approved. It only says who deployed it when the inputs are correct and someone registered them.

## Primary Actors

- deployers who want onchain provenance for hooks, clones, and helper contracts
- integrators who need to verify who deployed an address before trusting it
- reviewers who want a deterministic provenance check instead of offchain screenshots

## Key Surfaces

- `JBAddressRegistry`: stores `deployerOf[address]` after reconstructing the target address from deployment inputs
- `registerAddress(deployer, nonce)` and `registerAddress(deployer, salt, bytecode)`: the two provenance-registration paths

## Journey 1: Register A `CREATE` Deployment

**Actor:** deployer, operator, or reviewer with the original deployment inputs.

**Intent:** bind an already-deployed `create` address to the account that deployed it.

**Preconditions**
- the contract was deployed with `create`
- the caller knows the deployer address and nonce used for the deployment
- the address has not already been registered

**Main Flow**
1. Call `registerAddress(deployer, nonce)`.
2. `JBAddressRegistry` reconstructs the deployed address from the deployer and nonce.
3. If the computed address is valid and unused, the registry stores `deployerOf[address] = deployer`.

**Failure Modes**
- the nonce does not match the real deployment
- the computed address has already been registered
- the nonce exceeds the supported `uint64` range and registration reverts
- the deployment assumptions are wrong and the reconstructed address is useless

## Journey 2: Register A `CREATE2` Deployment

**Actor:** deployer, operator, or reviewer with the original deterministic deployment inputs.

**Intent:** bind a `create2` deployment to its deployer without privileged access.

**Preconditions**
- the contract was deployed with `create2`
- the caller knows the deployer, salt, and init code
- the address has not already been registered

**Main Flow**
1. Call `registerAddress(deployer, salt, bytecode)`.
2. The registry reconstructs the deterministic address from the standard `create2` formula.
3. If the address is valid and unused, the registry records the deployer.

**Failure Modes**
- the bytecode or salt is wrong
- the address was registered already
- a third party publishes the first valid provenance claim before the expected deployer registers it
- operators assume registration proves a contract exists there right now
- consumers misread provenance as an allowlist or review stamp

## Journey 3: Resolve Provenance For An Existing Address

**Actor:** integrator, frontend, or reviewer.

**Intent:** answer "who deployed this?" before trusting a hook, helper, or clone.

**Preconditions**
- the address was registered previously
- the caller understands that an empty result means "unknown" rather than "unsafe"

**Main Flow**
1. Query `deployerOf[address]`.
2. If a deployer is present, use it as provenance evidence for who originated the deployment.
3. If no deployer is present, treat the address as unregistered and keep investigating elsewhere.
4. Pair the result with an external trust list, transaction history, or review context before relying on the contract.

**Postconditions**
- downstream reviewers know which deployer or factory to inspect next
- the trust decision still happens outside this repo

## Trust Boundaries

- this repo only proves registered deployer provenance from deterministic inputs
- anyone can submit a valid claim, so the mapping authenticates deployment inputs rather than caller identity
- it does not prove code quality, review status, or governance approval

## Hand-Offs

- Use this repo together with the relevant deployer repo when provenance of clones, hooks, or helper contracts matters.
- Use [deploy-all-v6](../deploy-all-v6/USER_JOURNEYS.md) or a package-specific deployer repo when the question is about deployment sequencing rather than provenance recording.
