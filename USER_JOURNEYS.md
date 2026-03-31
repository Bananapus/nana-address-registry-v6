# User Journeys

## Who This Repo Serves

- deployers publishing deterministic contract addresses
- integrators verifying where a contract came from
- auditors checking provenance across factories and CREATE2 deployments

## Journey 1: Register A Deterministic Deployment

**Starting state:** a factory or deployer is creating contracts and wants a canonical provenance record.

**Success:** the deployed address is mapped back to the deployer that created it.

**Flow**
1. Deploy the contract with `create` or `create2`.
2. Call the appropriate `registerAddress(...)` overload with the deployer information and deployment inputs needed to reconstruct the address.
3. Emit the registry event so downstream tooling can index the deployment.
4. Use the registry as the source of truth when other repos need to prove where a clone or hook came from.

## Journey 2: Resolve Provenance For An Existing Address

**Starting state:** you have a contract address and need to know whether it is an official deployment from a known factory.

**Success:** you can programmatically confirm the deployer of record.

**Flow**
1. Query the registry for the address in question.
2. Compare the returned deployer against the factory or deployer you trust.
3. Use that answer to admit or reject the address inside higher-level integrations.

## Hand-Offs

- This repo is a utility, not an end-user product. It matters most when reading [nana-buyback-hook-v6](../nana-buyback-hook-v6/USER_JOURNEYS.md), [univ4-lp-split-hook-v6](../univ4-lp-split-hook-v6/USER_JOURNEYS.md), and other factory-driven packages.
