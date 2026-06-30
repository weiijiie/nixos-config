# Code style

## Naming

- Plain words over jargon.
- One term per concept; don't drift between synonyms.
- Don't bake provenance or call-site detail into a name when the plain noun
  suffices.

## Structure

- Smallest footprint: prefer the minimal change; inline single-use helpers
  where appropriate; treat a ballooning diff as an indication to simplify.
- Minimize surface area: private unless it must be public.
- Keep sibling functions consistent in shape and return type.
- Encapsulate detail logic inside the function that owns it; don't leak it into
  the caller's control flow.
- Prefer simple over clever. An implementation that looks oddly complicated usually is.

## Tests

- Table-driven for structurally similar cases.
- No duplicate coverage.
- Don't test tautological code (e.g. a switch-case mapping).
- Do test the invariants other code depends on — not just the happy path.

## Correctness

- When you change how values or errors flow, prove you didn't break contracts
  callers rely on (type assertions, status codes, retry semantics). Verify,
  don't assume.
- Be skeptical of band-aids; understand the mechanism before accepting it.
