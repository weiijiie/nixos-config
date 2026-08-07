# Workflow

## Tickets and PRs

- When working a Linear issue, read the issue comments as well as the
  description before designing or changing behavior; comments often carry
  binding design amendments that supersede the description.
- When review feedback is arriving iteratively, accumulate the fixes and
  commit/push once the round is complete; don't commit per item.
- When simplifying or restructuring a PR, fix only problems the PR's diff
  introduced; leave pre-existing patterns and file organization alone even
  when review finds them. Out-of-scope refactors bloat the diff.
- In PR descriptions and docs, don't present a measurement from one project
  or sample as a general fact; describe the mechanism qualitatively unless
  the number is representative.

## Unverified claims

- Never assert an unchecked fact about how a system behaves or is used,
  whether in a code comment, a design justification, or a scoping decision.
  Verify it, ask, or hedge explicitly.
- Don't narrow a change across a fleet of similar instances (service
  variants, clusters, configs) on an assumption about which ones matter.
  Cover them all unless you have checked.
- When a normalized or per-unit number shows unexplained skew across a
  population, first enumerate what the denominator leaves out (scale,
  volume, unmatched numerator terms) and test those. Reach for
  mechanism-specific causes only once the first-order confounders are ruled
  out.

## Shared mutable artifacts

Notion pages, PR descriptions, wikis, and other documents the user edits too.

- Fetch the live version and merge your change into it before writing. Never
  push a stale local snapshot over one.
- Content missing between your writes is not evidence of a tool error. The
  user may have deleted it deliberately. Confirm, or check the edit history,
  before restoring anything you did not just write.

## Git

- After committing a multi-step change, verify `git status` is clean for the
  touched paths before reporting done.
- Never redirect `git add` or `git commit` stderr to /dev/null. A stale
  pathspec aborts the whole add silently.

## Claude Code shell

- Don't put tilde/home paths in shell variable assignments (VAR=~/path).
  The sandbox flags the assignment and prompts for permission. Inline the
  path at each use, or cd once in a dedicated call.
