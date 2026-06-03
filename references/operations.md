# Address Registry Operations

## Change checklist

- If you edit `create` reconstruction logic, verify nonce-boundary behavior.
- If you edit `create2` behavior, verify bytecode hashing and salt assumptions.
- If a user asks whether a contract is "safe," redirect the question to code provenance plus code review, not the registry alone.
- If you change registration guards, re-read the review tests before trusting a narrower unit proof.

## Common failure modes

- Operators confuse deployer provenance with trustworthiness.
- Registration is attempted with stale deployment inputs from another repo or environment.
- The wrong party is allowed to bind or front-run a computed address because the first-write assumption was weakened.
