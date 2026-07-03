# Feedback loop: /give-feedback → WAL → /synthesize-rules → promote

A self-improvement loop for agent behavior. Corrections given during work are
captured, lightly generalized into provisional rules that take effect
immediately, periodically synthesized into curated stores, and — for shared
destinations — promoted onward after a local soak period.

The system is a set of loop instances sharing one pipeline. Each instance
scopes what it captures (global behavior vs. per-project domain knowledge)
and where synthesized output lands. The pipeline has LSM-tree shape: feedback
appends to a WAL; compaction moves content up tiers; each tier is more
general, more curated, and more expensive to change.

A simpler global-only version of this design is checkpointed at
`2026-07-03-feedback-loop-design-v1-global-only.md`.

## Goals

- Capture corrections with near-zero friction, including feedback given
  organically (not via explicit skill invocation). Not just code style: tool
  usage, shell habits, workflow, communication — any correction of how the
  agent works — plus per-project domain knowledge.
- New guidance takes effect in the very next session, without a rebuild.
- Curated stores are not append-only: synthesis merges, re-ranks,
  generalizes, and prunes.
- Synthesized artifacts destined for shared stores are validated locally
  (live in the author's own sessions) before promotion.
- The skills are portable: no personal paths in skill logic, so the workflow
  itself can be distributed to the team via `manage-skills`.
- All personal wiring is reproducible across machines via nixos-config; only
  WAL/staging content is machine-local mutable state.

## Loop instances and tiers

| | Global loop (phase 1) | Project loop (phase 2) |
|---|---|---|
| Captures | behavioral rules: code style, workflow, environment | domain knowledge for one project |
| WAL | `~/.claude/feedback/global/` | `~/.claude/feedback/projects/<slug>/` |
| Injected | every session | sessions in that project only |
| Tier 2 (curated) | `home/claude-rules/` + pointer-backed skills in nixos-config | staged: `staged-rules.md` next to the WAL, or draft skill in claude-sandbox |
| Tier 3 (shared) | — (personal repo; staging and destination coincide) | team repo (CLAUDE.md section or team skill), via `manage-skills` PR |

Each instance is defined by a config file, not by skill logic:

```markdown
# ~/.claude/feedback/projects/analytics/config.md
scope: project (analytics, /home/weijie_huang/analytics)
tiers:
  1. WAL + active-rules (auto-injected in this project's sessions)
  2. staged-rules.md + claude-sandbox drafts (live for me; soak before promoting)
  3. analytics repo, via manage-skills PR
```

The global instance's config points tier 2 at nixos-config and has no tier 3.
First invocation in an environment with no config scaffolds one
interactively. Skill behavior differences per destination type are prose
paragraphs in the skill, selected by the config — the capture format and
synthesis contract are identical across instances and must stay that way.

## Components

| Piece | Location | Managed by |
|---|---|---|
| `/give-feedback` skill | `skills/give-feedback/` | git + existing skills symlink wiring |
| `/synthesize-rules` skill | `skills/synthesize-rules/` | git + existing skills symlink wiring |
| Auto-trigger rule | `home/claude-rules/feedback-loop.md` | git + `rulesDir` (always injected) |
| Injection hook | `SessionStart` hook in `home/claude-code.nix` settings | nix rebuild |
| Loop configs | `config.md` per loop instance under `~/.claude/feedback/` | scaffolded by skill, hand-editable |
| WAL + staging | `active-rules.md`, `wal.md`, `staged-rules.md` per instance | agents, machine-local |

## WAL

Per instance, created by `/give-feedback` on first write (no seeding; the
injection hook no-ops while files are absent).

### `active-rules.md` — injected, lean

One line per provisional rule, plus a fixed header framing them as binding:

```markdown
# Provisional rules (from recent feedback; obey like committed rules)
- R003: Don't wrap errors with messages that restate the function name.
- R007: In table-driven Go tests, name cases by behavior, not by input values.
```

Every line here is paid for in every session it is injected into, so this
file holds only rule text and IDs. Near-duplicate lines are not added: if an
equivalent provisional rule already exists, only the evidence lands in
`wal.md`.

### `wal.md` — append-only evidence, never injected

One block per entry. Existing entries are never edited or merged; recurrence
is expressed with a soft `relates-to` link and resolved at synthesis time,
which has full context. Merging at capture time is forbidden because a wrong
merge destroys evidence irrecoverably.

```markdown
## R003 — redundant error-wrap messages
created: 2026-07-03 | kind: code-style | scope: go, general?
relates-to: —
rule: Don't wrap errors with messages that restate the function name.
instances:
- 2026-07-03 analytics: "why does every fmt.Errorf repeat the func name" —
  fix removed 6 redundant prefixes in lqs/executor
```

- `kind` is one of `code-style | workflow | environment | domain` and drives
  loop routing at capture: `domain` entries go to the current project's loop,
  everything else to the global loop. Keeping domain knowledge out of the
  global loop is a hard rule — otherwise global rules bloat with
  project-specific facts paid for in every unrelated session.
- `scope` is a hint (general / language / purpose); the destination decision
  is made at synthesis.
- Entries judged one-off at capture time are still appended (evidence-only,
  no `active-rules.md` line) so synthesis can spot a pattern later.
- IDs are monotonically increasing (`R###`) per instance, assigned at append.

## `/give-feedback` flow

1. **Collect** — feedback from invocation args plus any correction-style
   feedback given earlier in the conversation that was not yet logged.
2. **Fix** — apply the feedback to the current work first, when there is
   something to apply it to (a changeset, a redone command). Pure behavioral
   corrections with nothing to redo go straight to the next step.
3. **Generalize** — cluster the session's feedback (multiple corrections of
   the same issue in different places form one cluster), draft a 1–2 line
   candidate rule per cluster with kind and scope hints.
4. **Sanity check (cheap)** — contradiction scan against committed rules,
   injected provisional rules, and staged rules, all already in context.
   Contradictions are surfaced to the user immediately, not logged silently.
   A correction that contradicts a *staged* rule is recorded as negative
   evidence against it (this is the soak signal). Judge generalizability:
   one-offs become evidence-only entries.
5. **Route and write** — pick the loop instance by `kind` (domain → current
   project's loop; else global), append to that instance's `wal.md`, update
   its `active-rules.md` for non-duplicate generalizable rules.
6. **Threshold check** — per instance: suggest `/synthesize-rules` in a fresh
   session when the WAL has ≥ 10 entries, or the oldest entry is ≥ 14 days
   old and there are more than 2 entries.
7. **Report** — one-line summary of what was fixed and what was logged where.

## `/synthesize-rules` flow

Run in a fresh session, targeting one loop instance (rewriting a curated
store needs clean context).

1. Read the instance's config, `wal.md`, `active-rules.md`, `staged-rules.md`
   if present, and the tier-2 store (for global: all of `home/claude-rules/`
   and pointer-backed skills).
2. **Cluster and route** each entry, weighted by recurrence (via `relates-to`
   links and its own reading):
   - merge into an existing tier-2 rule,
   - new rule in the tier-2 store,
   - new or updated skill for niche/bulky guidance (language- or
     purpose-specific, e.g. perf patterns), backed by a one-line pointer in
     an always-injected rule so loading is near-deterministic,
   - carry forward in the WAL (insufficient evidence yet),
   - drop (stale one-off) — dropped entries are listed for the user, never
     silently discarded.
3. **Deep evaluation** of every promoted candidate: sample real code and
   recent diffs from the repos the rule targets; verify the rule would not
   flag reasonable existing code (false-positive test) and that the WAL
   instances genuinely support the generalization rather than one incident
   phrased twice.
4. **Rewrite tier 2 holistically** — merge, re-rank, tighten, prune.
   Explicitly not append-only. For the global loop tier 2 is the final
   destination (present git diff, commit on approval, remind the user to run
   `home-manager switch`). For loops with a tier 3, output lands in the
   staged tier (`staged-rules.md`, injected for the author's sessions;
   draft skills in claude-sandbox) and starts its soak.
5. **Promotion check** — for staged artifacts from previous runs: if soaked
   (≥ 2 weeks live with no negative evidence captured against them), suggest
   promotion. Promotion is always user-initiated; it produces the tier-3
   artifact (PR via `manage-skills`, or a CLAUDE.md section change). A staged
   artifact whose promotion PR is not yet merged is carry-forward, not done.
6. **Compact the WAL** — remove synthesized and dropped entries, keep
   carried-forward entries with their history, shrink `active-rules.md`.
   This is the only operation allowed to rewrite `wal.md`.

## Auto-trigger rule (`home/claude-rules/feedback-loop.md`)

Always-injected, roughly three sentences:

1. When the user corrects how you work — code style, structure, tool usage,
   shell habits, workflow, communication; not task-specific bug reports —
   invoke `/give-feedback` after addressing it. Corrections of factual
   project knowledge count too (they route to the project loop).
2. Provisional and staged rules injected at session start are binding, same
   as these rules.
3. Never proactively solicit feedback.

## Injection hook

`SessionStart` hook (matcher `startup|clear|compact`) added to
`claudeCodeSettings.hooks` in `home/claude-code.nix`, command pointing at a
`pkgs.writeShellScript`:

- Reads the hook input JSON for the cwd, maps it to a project slug.
- Concatenates whichever of these exist and are non-empty: global
  `active-rules.md`, the project's `active-rules.md`, the project's
  `staged-rules.md`.
- Emits the result as `hookSpecificOutput.additionalContext` JSON (the
  mechanism superpowers' session-start hook uses, verified working);
  otherwise exits 0 silently.

This keeps `~/.claude/CLAUDE.md` untouched (tools like rtk keep writing to
it freely) and needs no activation script. Hook-injected text arrives as
session context rather than user instructions, so injected content leads
with the binding framing shown in the `active-rules.md` header.

## Portability

The skills contain no personal paths, repo names, or wiring assumptions —
those live in loop configs and the environment:

- Skill = engine: flows, file formats, tier semantics.
- Config = instance data: scopes, paths, tier destinations.
- Injection wiring = environment adapter: nix-managed hook here; a project
  `.claude/settings.json` hook (committed, shareable) or a documented
  one-liner for teammates. The skills only write the files; the environment
  is responsible for injecting them.

A teammate's scaffolded default config uses destinations everyone has (e.g.
`~/.claude/CLAUDE.md` sections as tier 2). This separation is what lets the
feedback-loop skills themselves be promoted to the team via `manage-skills`.

## Phasing

- **Phase 1 — global loop.** Everything above for the global instance only:
  both skills, auto-trigger rule, injection hook (already reading per-project
  paths, which simply don't exist yet), config file format with a single
  global instance. No staged tier in practice (tier 2 is final), but skill
  text and formats are written instance-generically from day one. `kind:
  domain` feedback is not yet WAL-routed: it goes to the existing per-project
  memory, and the skill says so.
- **Phase 2 — project loops.** `kind: domain` routing goes live, per-project
  WALs, staged tier + soak + promotion, the analytics three-tier instance as
  reference case, team distribution of the skills.

## Known limitations (accepted)

- **WALs and staging are per-machine.** Divergence is bounded by synthesis
  cadence, since curated stores deploy everywhere. Future option: sync
  `~/.claude/feedback/` via git.
- **Concurrent sessions** may interleave WAL appends. Entries are
  independent markdown blocks, so the worst case is ordering noise. ID
  collisions between simultaneous appends are possible but harmless — IDs
  only need to be unique enough for `relates-to` links.
- Injected `active-rules.md`/`staged-rules.md` cost tokens in every session
  they apply to; lean formats and synthesis compaction bound it.
- Skill loading for pointer-backed skills is near-deterministic, not
  guaranteed.
- Soak validation is passive (absence of corrections), so rarely-exercised
  staged rules can soak to promotion without real evidence. The user's
  promotion review is the backstop.

## Alternatives considered

**Compile-time templating.** Instead of one config-driven skill, a wizard
skill interactively collects an environment's answers (scopes, destinations,
wiring) and generates a concrete, specialized feedback-loop skill per
environment. Advantage: each generated skill is simple and literal — no
config indirection for the executing agent to follow, which tends to improve
prose-skill adherence. Disadvantage: N generated copies drift, and engine
improvements don't propagate without regeneration. Deferred, not rejected;
the approaches compose (a wizard could generate the *config* for the
runtime-config design, keeping one engine). Revisit if config-driven skill
adherence proves unreliable in practice.

## Testing

- Dry-run `/give-feedback` with synthetic feedback: verify fix-first
  ordering, session-level dedupe, kind routing, evidence-only handling of
  one-offs, contradiction surfacing (including negative evidence against
  staged rules), threshold suggestions at both boundaries.
- Verify the SessionStart hook: absent files → no output; each combination
  of global/project/staged files present → valid JSON, content visible in a
  new session, correct project matching from cwd.
- Dry-run `/synthesize-rules` against a fabricated WAL: verify routing
  categories, dropped entries reported, compaction preserves carried-forward
  history, staged output for tier-3 loops vs. direct commit for the global
  loop, soak/promotion suggestions, and that pending-PR artifacts are
  carried forward.
