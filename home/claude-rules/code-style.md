# Code style

## Naming

These cover every place a name or a term appears: identifiers, CLI flags and
tool names, comments, prose in docs, and what you write in chat.

- Plain words over jargon; don't coin terms the team doesn't already use.
  If a new term is unavoidable, define it once where it's introduced and
  name the symbols built on it consistently.
- Never invent a shorthand for something the code already names. Name the
  identifier and say what it does; a reader should not need the conversation
  to decode the phrase. Label a thing by its name, not by a symbol.
- Plain language means avoiding jargon, not avoiding accurate common
  vocabulary. Prefer the field's standard term (nodes, edges, graph,
  memoized) over a physical metaphor invented to sound simpler (dots, lines,
  stroke) or a plainer circumlocution (remembered).
- One term per concept, and one concept per term. Don't drift between
  synonyms, and check a new term against the codebase's existing vocabulary
  before introducing it: reusing an established name for a different thing is
  worse than spelling out the specifics.
- Don't bake provenance or call-site detail into a name when the plain noun
  suffices.
- When a concept has several representations in scope (its name, its
  directory, an index), the identifier says which one it holds: `runName`
  and `runDir`, never a bare `run` or `dir`. A longer name that
  disambiguates beats a short one that doesn't.

## Structure

- Smallest footprint: prefer the minimal change; inline single-use helpers
  where appropriate; treat a ballooning diff as an indication to simplify.
  To make existing code also run in another case, extend it in place (move a
  line, widen a guard) rather than extracting a wrapper or a helper.
- Minimize surface area: private unless it must be public.
- Keep sibling functions consistent in shape and return type.
- Encapsulate detail logic inside the function that owns it; don't leak it into
  the caller's control flow.
- Don't repeat the same guard at every call site (verbosity checks and the
  like); wrap it once in a small helper and call that. But a helper that
  takes the identity of what it acts on as a parameter is indirection, not
  deduplication: inline it and accept the few duplicated lines.
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

## Go

- Use if/else if for two-branch error or outcome classification. Reserve a
  tagless switch for three or more genuinely parallel cases.

## Observability

- Open a unit of work's logging/tracing scope at the top of the function
  doing the work, not inline at the first logging call further down.
- Inline a metric, event, or log emission at each call site rather than
  extracting a helper that threads the metric name through a parameter.
- Don't emit a synthetic value to make a series exist. Give the counter an
  outcome label so its success side moves with real traffic, and make the
  alert query no-data-proof (`or vector(0)`) instead.

## Tests

- Cover a behavior change with a test through the entry point the behavior
  serves, not a unit test per helper. Unit-test a helper only for cases the
  entry point can't reach or can't enumerate cheaply (parsing edge cases,
  boundary arithmetic).
- Table-driven for structurally similar cases.
- No duplicate coverage.
- Don't test tautological code (e.g. a switch-case mapping).
- Do test the invariants other code depends on, not just the happy path.

## Correctness

- When you change how values or errors flow, prove you didn't break contracts
  callers rely on (type assertions, status codes, retry semantics). Verify,
  don't assume.
- Be skeptical of band-aids; understand the mechanism before accepting it.
