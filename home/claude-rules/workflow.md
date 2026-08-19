# Workflow

## Scope

- Answer the question that was asked, at the scope it was asked. A narrow
  syntax or how-to question gets the answer, not an investigation of the
  surrounding system. If extra digging looks warranted, say so in a sentence
  and let the user ask for it.

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
  Only land on an existing PR's branch when the user names it.
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
  Verify it, ask, or hedge explicitly.
- Your own notes are not a source. Before a plan, a sequencing decision, or a
  summary turns on what a review comment, a ticket, or a doc said, re-read the
  original text rather than your paraphrase of it in a state file or a memory
  note.
- A document's proposed solution is one candidate, not the anchor. Understand
  the problem first and derive the approach from that; it may legitimately
  diverge from what the document proposes.
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
- After committing a multi-step change, verify `git status` is clean for the
  touched paths before reporting done.
- Never redirect `git add` or `git commit` stderr to /dev/null. A stale
  pathspec aborts the whole add silently.

## Claude Code settings

`~/.claude/settings.json` is a read-only nix symlink; never write to it. Edit
the source in `~/nixos-config` instead (`home/claude-code.nix` for cross-host
settings, `home/mixpanel/devbox.nix` for devbox plugins and marketplaces), and
leave the `home-manager switch` to the user. Enabling a plugin also needs its
marketplace declared in `extraKnownMarketplaces`.

Settings nix does not manage live in `~/.claude/settings.local.json`, which is
writable: permissions, local hooks, and telemetry env.

## Claude Code shell

- Don't put tilde/home paths in shell variable assignments (VAR=~/path).
  The sandbox flags the assignment and prompts for permission. Inline the
  path at each use, or cd once in a dedicated call.
