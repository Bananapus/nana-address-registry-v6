# User Journeys

## Who This Repo Serves

- deployers that want on-chain provenance for helper contracts and hooks
- integrators checking who deployed an existing address
- auditors verifying deterministic deployment claims

## Journey 1: Register A `CREATE` Deployment

**Starting state:** you know the deploying address and nonce for a contract already created with `create`.

**Success:** the registry stores the verified deployer for the computed contract address.

**Flow**
1. Call the `registerAddress` overload for `create` deployments with the deployer and nonce.
2. `JBAddressRegistry` reconstructs the expected deployed address.
3. If the reconstruction matches a real address and no one registered it before, the registry stores `deployerOf[address]`.

## Journey 2: Register A `CREATE2` Deployment

**Starting state:** you know the deployer, salt, and init code for a deterministic deployment.

**Success:** the registry records the verified deployer for the deterministic address without any privileged access.

**Flow**
1. Call the `registerAddress` overload for `create2`.
2. The registry hashes deployer, salt, and deployment bytecode to reconstruct the deterministic address.
3. It stores the deployer for that address if the registration is valid and unused.

## Journey 3: Resolve Provenance For An Existing Address

**Starting state:** an integration or auditor sees a contract address and wants to know who deployed it.

**Success:** the caller can query `deployerOf[address]` and get provenance if someone registered it correctly.

**Flow**
1. Look up the address in the registry.
2. If a deployer is present, use that as provenance evidence for who originated the deployment.
3. Treat absence as "not registered," not as a trust verdict on the code.

## Hand-Offs

- Use this repo together with the relevant deployer repo when provenance of clones, hooks, or helper contracts matters.
- Use [deploy-all-v6](../deploy-all-v6/USER_JOURNEYS.md) or a package-specific deployer repo when the question is about deployment sequencing rather than provenance recording.
