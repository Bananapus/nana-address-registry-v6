# Address Registry Operations

## Change Checklist

- If you edit `create` reconstruction logic, verify nonce-boundary behavior.
- If you edit `create2` behavior, verify bytecode hashing and salt assumptions.
- If a user asks whether a contract is "safe," redirect the question to code provenance plus code review, not the registry alone.

## Common Failure Modes

- Operators confuse deployer provenance with trustworthiness.
- Registration is attempted with stale deployment inputs from another repo or environment.
