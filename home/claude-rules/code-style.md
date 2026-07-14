# Code style

## Naming

- Plain words over jargon; don't coin terms the team doesn't already use.
  If a new term is unavoidable, define it once where it's introduced and
  name the symbols built on it consistently.
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
- Don't repeat the same guard at every call site (verbosity checks and the
  like); wrap it once in a small helper and call that.
- Open a unit of work's logging/tracing scope at the top of the function
  doing the work, not inline at the first logging call further down.
- Prefer simple over clever. An implementation that looks oddly complicated usually is.

## Layout

These apply to code the change adds or restructures; don't reorder
pre-existing files just to comply.

- Callers first: place helpers below the function that calls them, so a file
  reads top-down from its entry points. Keep a type's constructor and
  closely-related helpers grouped with the type rather than strictly by
  call order.
- In functions that do a lot or nest deeply, separate logical stages (setup,
  I/O, results) with blank lines; when in doubt prefer more whitespace over
  less.
- Give a meaningful intermediate result its own named variable rather than
  nesting the call in a return or argument position.

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
