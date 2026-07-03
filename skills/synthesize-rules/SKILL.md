---
name: synthesize-rules
description: Compact the feedback WAL into the curated rule set — audit the WAL, cluster and evaluate candidate rules against real code, rewrite the rules holistically, and truncate the WAL. Run in a fresh session when give-feedback reports the WAL is ripe.
---

# Synthesize Rules

Rewrites tier 2 (the curated rule store) from accumulated WAL evidence.
Run in a fresh session with no other task in flight. Operates on the
global instance unless the user names another.

## 1. Read everything

`~/.claude/feedback/global/config.md`, `wal.md`, `active-rules.md`, and
the entire tier-2 store the config names — every rules file, plus any
skills those rules point at.

## 2. Audit the WAL

Before synthesizing, validate structure and report defect counts:

- entries missing kind, scope, rule, or instances
- non-monotonic or duplicate R### IDs
- active-rules.md lines with no backing WAL entry; generalizable WAL
  entries with no active-rules line
- near-identical active-rules lines that should have been deduped
- entries that belong to a different instance (e.g. domain entries in the
  global WAL)

Classify each defect: resolution error (capture followed the config to
the wrong place — wrong path, wrong instance, wrong destination) vs
process error (a capture step skipped or done wrong in the right place —
missed dedupe, missing or malformed fields). Report both counts to the
user —
this feeds the binding-time decision gate in the design spec. Defective
entries still get synthesized if their meaning is clear.

## 3. Cluster and route

Cluster entries via relates-to links plus your own reading. Weight by
recurrence: more instances and more related entries = higher priority.
Decide per cluster:

- merge into an existing tier-2 rule
- new rule in the tier-2 store
- new or updated skill for niche or bulky guidance (language- or
  purpose-specific, e.g. perf patterns), plus a one-line pointer in an
  always-injected rules file so it loads reliably; author or revise the
  skill with the skill-creator skill when it is available — it exists to
  make skills that trigger and perform well
- environment entries: prefer rephrasing into the portable form that is
  correct everywhere, keeping the machine-specific origin as evidence
  only; if irreducibly host-specific and tier 2 is host-aware (a nix repo
  with per-host configs), route to a host-scoped rules file; if tier 2 is
  not host-aware, keep it global
- carry forward — insufficient evidence yet
- drop — stale one-off; list every dropped entry for the user, never
  silently

## 4. Evaluate promotions

For each cluster becoming a rule, sample real code and recent diffs from
the repos the rule targets — actually read them, and cite the files or
commits examined; an invented example is not evidence. Check: (a) the
rule would not flag reasonable existing code — the false-positive test;
(b) the instances genuinely support the generalization rather than one
incident phrased twice. Demote failures to carry-forward or drop, and
say why.

## 5. Rewrite tier 2 holistically

Not append-only: merge overlapping rules, re-rank by importance, tighten
wording, prune rules the evidence says are dead. Rule text follows the
user's own writing rules. Provisional wording from active-rules.md is a
draft, not a constraint.

## 6. Review, commit, deploy

Present the complete diff (tier-2 store plus any skills) and wait for
approval. On approval commit; if tier 2 deploys via a rebuild (e.g.
home-manager switch), remind the user. The global instance has no staged
tier and no tier 3 — synthesized rules are final on commit. (Instances
with a tier 3 stage output for soak instead; see the design spec.)

## 7. Compact the WAL

Only after the tier-2 change is committed. This is the sole operation
allowed to rewrite wal.md: remove synthesized and dropped entries, keep
carried-forward entries byte-intact, and rewrite active-rules.md to hold
only the carried-forward generalizable rules (or delete it if none).
