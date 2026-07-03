# Feedback loop: /give-feedback → WAL → /synthesize-rules

A self-improvement loop for agent coding output. Corrections given on changesets
are captured, lightly generalized into provisional rules that take effect
immediately, and periodically synthesized into the committed global rule set.

## Goals

- Capture code-review-style feedback with near-zero friction, including
  feedback given organically (not via explicit skill invocation).
- New guidance takes effect in the very next session, without a rebuild.
- The permanent rule set is curated, not append-only: synthesis merges,
  re-ranks, generalizes, and prunes.
- All configuration is reproducible across machines via nixos-config; only the
  WAL content itself is machine-local mutable state.
- Rules are personal and global across all repos. No repo-specific CLAUDE.md
  files are written by this system.

## Components

| Piece | Location | Managed by |
|---|---|---|
| `/give-feedback` skill | `skills/give-feedback/` | git + existing skills symlink wiring |
| `/synthesize-rules` skill | `skills/synthesize-rules/` | git + existing skills symlink wiring |
| Auto-trigger rule | `home/claude-rules/feedback-loop.md` | git + `rulesDir` (always injected) |
| WAL injection hook | `SessionStart` hook in `home/claude-code.nix` settings | nix rebuild |
| WAL | `~/.claude/feedback/active-rules.md`, `~/.claude/feedback/wal.md` | agents, machine-local |

## WAL

Two files under `~/.claude/feedback/`, created by `/give-feedback` on first
write (no seeding step; the injection hook no-ops while they are absent).

### `active-rules.md` — injected, lean

One line per provisional rule, plus a fixed header framing them as binding:

```markdown
# Provisional rules (from recent feedback; obey like committed rules)
- R003: Don't wrap errors with messages that restate the function name.
- R007: In table-driven Go tests, name cases by behavior, not by input values.
```

Every line here is paid for in every session, so this file holds only rule
text and IDs. Near-duplicate lines are not added: if an equivalent provisional
rule already exists, only the evidence lands in `wal.md`.

### `wal.md` — append-only evidence, never injected

One block per entry. Existing entries are never edited or merged; recurrence
is expressed with a soft `relates-to` link and resolved at synthesis time,
which has full context. Merging at capture time is forbidden because a wrong
merge destroys evidence irrecoverably.

```markdown
## R003 — redundant error-wrap messages
created: 2026-07-03 | scope: go, general?
relates-to: —
rule: Don't wrap errors with messages that restate the function name.
instances:
- 2026-07-03 analytics: "why does every fmt.Errorf repeat the func name" —
  fix removed 6 redundant prefixes in lqs/executor
```

- `scope` is a hint (general / language / module / purpose, e.g. perf); the
  routing decision is made at synthesis.
- Entries judged one-off at capture time are still appended (evidence-only,
  no `active-rules.md` line) so synthesis can spot a pattern later.
- IDs are monotonically increasing (`R###`), assigned at append time.

## `/give-feedback` flow

1. **Collect** — feedback from invocation args plus any correction-style
   feedback given earlier in the conversation that was not yet logged.
2. **Fix** — apply the feedback to the current changeset first. Implementing
   the fix grounds the generalization.
3. **Generalize** — cluster the session's feedback (multiple corrections of
   the same issue in different places form one cluster), draft a 1–2 line
   candidate rule per cluster with a scope hint.
4. **Sanity check (cheap)** — contradiction scan against committed rules and
   `active-rules.md`, both already in context. Contradictions are surfaced to
   the user immediately, not logged silently. Judge generalizability:
   one-offs become evidence-only entries.
5. **Write** — append entries to `wal.md` (with `relates-to` links where
   applicable); add `active-rules.md` lines for generalizable rules that do
   not duplicate an existing line.
6. **Threshold check** — suggest running `/synthesize-rules` in a fresh
   session when either: the WAL has ≥ 10 entries, or the oldest entry is
   ≥ 14 days old and there are more than 2 entries.
7. **Report** — one-line summary of what was fixed and what was logged.

## `/synthesize-rules` flow

Run in a fresh session in nixos-config (rewriting the whole rule set needs
clean context).

1. Read `wal.md`, `active-rules.md`, all of `home/claude-rules/`, and any
   existing pointer-backed skills.
2. **Cluster and route** each entry, weighted by recurrence across entries
   (via `relates-to` links and its own reading):
   - merge into an existing committed rule,
   - new general rule in `home/claude-rules/`,
   - new or updated skill for niche/bulky guidance (language- or
     purpose-specific, e.g. perf patterns), backed by a one-line pointer in a
     rules file so loading is near-deterministic,
   - carry forward in the WAL (insufficient evidence yet),
   - drop (stale one-off) — dropped entries are listed for the user, never
     silently discarded.
3. **Deep evaluation** of every promoted candidate: sample real code and
   recent diffs from the repos the rule targets; verify the rule would not
   flag reasonable existing code (false-positive test) and that the WAL
   instances genuinely support the generalization rather than one incident
   phrased twice.
4. **Rewrite holistically** — merge, re-rank, tighten, and prune the
   committed rules. Explicitly not append-only.
5. Present the git diff (`home/claude-rules/` + `skills/`) for user review,
   commit on approval, remind the user to run `home-manager switch`.
6. **Compact the WAL** — remove promoted and dropped entries, keep
   carried-forward entries with their history, shrink `active-rules.md`
   accordingly. This is the only operation allowed to rewrite `wal.md`.

## Auto-trigger rule (`home/claude-rules/feedback-loop.md`)

Always-injected, three sentences:

1. When the user gives correction-style feedback on code you produced —
   style, structure, approach; not task-specific bug reports — invoke
   `/give-feedback` after addressing it.
2. Provisional rules injected at session start are binding, same as these
   rules.
3. Never proactively solicit feedback.

## WAL injection hook

`SessionStart` hook (matcher `startup|clear|compact`) added to
`claudeCodeSettings.hooks` in `home/claude-code.nix`, command pointing at a
`pkgs.writeShellScript`:

- If `~/.claude/feedback/active-rules.md` exists and is non-empty, emit its
  content as `hookSpecificOutput.additionalContext` JSON (the mechanism
  superpowers' session-start hook uses, verified working).
- Otherwise exit 0 with no output.

This keeps `~/.claude/CLAUDE.md` untouched (tools like rtk keep writing to it
freely) and needs no activation script. Hook-injected text arrives as session
context rather than user instructions, so the injected content leads with the
binding framing shown in the `active-rules.md` header.

## Known limitations (accepted)

- **WAL is per-machine.** Feedback on one machine does not reach another's
  WAL. Divergence is bounded by synthesis cadence, since committed rules
  deploy everywhere. Future option: sync `~/.claude/feedback/` via git.
- **Concurrent sessions** may interleave WAL appends. Entries are independent
  markdown blocks, so the worst case is ordering noise. ID collisions between
  simultaneous appends are possible but harmless — IDs only need to be
  unique enough for `relates-to` links, and synthesis reads blocks, not IDs.
- The injected `active-rules.md` costs tokens in every session; the
  one-line-per-rule format and synthesis compaction bound it.
- Skill loading for pointer-backed skills is near-deterministic, not
  guaranteed.

## Testing

- Dry-run `/give-feedback` with synthetic feedback: verify fix-first
  ordering, session-level dedupe, evidence-only handling of one-offs,
  contradiction surfacing, threshold suggestions at both boundaries.
- Verify the SessionStart hook: absent file → no output; populated file →
  valid JSON, content visible in a new session.
- Dry-run `/synthesize-rules` against a fabricated WAL: verify routing
  categories, that dropped entries are reported, that the WAL compaction
  preserves carried-forward history, and that the diff touches only
  `home/claude-rules/` and `skills/`.
