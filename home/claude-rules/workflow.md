# Workflow

## Tickets and PRs

- When working a Linear issue, read the issue comments as well as the
  description before designing or changing behavior — comments often carry
  binding design amendments that supersede the description.
- When review feedback is arriving iteratively, accumulate the fixes and
  commit/push once the round is complete; don't commit per item.
- When simplifying or restructuring a PR, fix only problems the PR's diff
  introduced; leave pre-existing patterns and file organization alone even
  when review finds them — out-of-scope refactors bloat the diff.
- In PR descriptions and docs, don't present a measurement from one project
  or sample as a general fact; describe the mechanism qualitatively unless
  the number is representative.

## Claude Code shell

- Don't put tilde/home paths in shell variable assignments (VAR=~/path) —
  the sandbox flags the assignment and prompts for permission. Inline the
  path at each use, or cd once in a dedicated call.
