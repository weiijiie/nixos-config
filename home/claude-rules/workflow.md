# Workflow

## Scope

- Answer the question that was asked, at the scope it was asked. A narrow
  syntax or how-to question gets the answer, not an investigation of the
  surrounding system. If extra digging looks warranted, say so in a sentence
  and let the user ask for it.

## Design and review judgment

- Calibrate the robustness bar to what the component is for. Debug, replay,
  and dev tooling need no consistency across restarts, resharding, or
  topology change. Before rejecting a reviewer's simplification, name the
  narrowest property the code actually has to hold.
- Before calling a change too complex, or cutting scope in the name of
  simplicity, read the code and attribute its lines to purposes, then check
  each purpose against the goal. A diffstat is not evidence of complexity,
  and a requirement the goal depends on is not a simplification candidate.

## Tickets and PRs

- When working a Linear issue, read the issue comments as well as the
  description before designing or changing behavior; comments often carry
  binding design amendments that supersede the description.
- Read a PR's live state (draft or ready, base, open or closed) with
  `gh pr view` at the moment you act on it, never from a memory note or an
  earlier session's claim, and never repeat a remembered status back as fact.
- Default new work to a fresh branch off the latest upstream default branch,
  and name that branch when you offer to commit. Never push onto a branch
  whose PR is open for review, even for the same ticket or the same files.
  Only land on an existing PR's branch when the user names it. When a
  scratch edit turns out to be a real fix, move it to such a branch in the
  same turn; don't leave it uncommitted on the default-branch checkout.
- Don't couple a PR onto an open one just because the two touch the same
  files. An observability or metrics change ships separately from a behavior
  fix unless one genuinely needs the other's code.
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
  Verify it, ask, or hedge explicitly. When a shared artifact scopes an
  option out, say how deeply it was investigated; one docs line or a single
  probe does not make a firm out-of-scope call.
- An inference stays labeled as one until it is checked. That includes
  blaming a failure on a difference between variants from a few
  observations, naming which service runs a workload from which product
  submits it, and repeating a subagent's reading of patterns as fact. Don't
  call an existing setting wrong ("inverted", "mis-set") before reading its
  history; say what is unusual about it instead.
- Reach for the cheapest evidence first. Read a tool's config, state, and log
  files before grepping or disassembling its binary. Run a command with a
  safe flag (`--help`, `--dry-run`) before inferring its behavior from
  source. Stop and answer once the evidence is in hand.
- A source read is not confirmation. Where a repo holds several
  implementations of the same tool, one code path predicts nothing about
  which one runs; run it or ask. Follow the code that resolves a name (alias
  tables, param types, fallbacks) before reporting a name or value mismatch
  as a bug.
- Before writing that data is safe to delete, verify the stated recovery path
  reproduces it. A re-fetch that returns different content is not recovery.
  Say what is guaranteed and what is not.
- Your own notes are not a source. Before a plan, a sequencing decision, or a
  summary turns on what a review comment, a ticket, or a doc said, re-read the
  original text rather than your paraphrase of it in a state file or a memory
  note.
- A document's proposed solution is one candidate, not the anchor. Understand
  the problem first and derive the approach from that; it may legitimately
  diverge from what the document proposes.
- Don't narrow a change across a fleet of similar instances (service
  variants, clusters, configs) on an assumption about which ones matter.
  Cover them all unless you have checked. The same holds for documentation:
  grep the repo for a checked-in runbook on the subject (docs/, README,
  product directories) and update every copy, rather than calling an
  external page the only one.
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
  before restoring anything you did not just write. A clobbered GitHub PR body
  is recoverable from the GraphQL `userContentEdits` field.

## Git

- Before proposing an action that discards or rewrites existing work (a
  force-push, a squash, an overwrite), state what is lost and how much of it:
  "this squashes your 30 commits into one", not "the result is the base tip
  plus one commit". Describing the outcome is not disclosing the cost.
- Keep a stacked branch rebased onto its base; never merge the base into it,
  which pins stale base commits into the branch's history and re-raises the
  conflicts you already resolved. When a base is rewritten, rebase the whole
  chain. Look for a stack helper (the `gh stack` extension, the gh-stack
  skill) before hand-rolling this.
- When opening a PR on top of another open PR's branch, register the pair as
  a stack at creation: `gh stack link <bottom-PR> <top-PR>` (PR numbers, so
  nothing is pushed), then `gh stack checkout <stack#>` for local tracking.
  Setting `--base` alone is not a stack.
- After committing a multi-step change, verify `git status` is clean for the
  touched paths before reporting done.
- Never redirect `git add` or `git commit` stderr to /dev/null. A stale
  pathspec aborts the whole add silently.

## Claude Code settings

`~/.claude/settings.json` is a writable file that both nix and Claude Code
write. Every `home-manager switch` merges the declared keys over it, so a key
nix declares has to change in `~/nixos-config` (`home/claude-code.nix` for
cross-host settings, `home/mixpanel/devbox.nix` for devbox), and the switch is
the user's to run. Keys nix does not declare, plugins and marketplaces among
them, survive the merge; change those in place or through `/config`, `/plugin`
and the rest.

`~/.claude/settings.local.json` is outside nix entirely: permissions, local
hooks, and telemetry env.

## Claude Code shell

- Don't put tilde/home paths in shell variable assignments (VAR=~/path).
  The sandbox flags the assignment and prompts for permission. Inline the
  path at each use, or cd once in a dedicated call.
