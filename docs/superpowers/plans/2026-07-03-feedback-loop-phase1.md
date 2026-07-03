# Feedback Loop Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the global feedback loop: `/give-feedback` capture skill, `/synthesize-rules` synthesis skill, an always-injected auto-trigger rule, and a SessionStart hook that injects provisional rules into every session.

**Architecture:** Corrections are captured into an append-only WAL at `~/.claude/feedback/global/` with a lean `active-rules.md` injected at session start by a nix-managed hook. A separate synthesis skill periodically compacts the WAL into `home/claude-rules/`. Skills are prose engines with no personal paths; instance data lives in `~/.claude/feedback/global/config.md`, scaffolded by a first-run wizard. Spec: `docs/superpowers/specs/2026-07-03-feedback-loop-design.md`.

**Tech Stack:** Claude Code skills (markdown), home-manager/nix (`home/claude-code.nix`), bash + jq (hook script).

## Global Constraints

- Commits: lowercase short subjects, ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. Pre-commit needs the dev shell: commit via `nix develop -c git commit ...` from `~/nixos-config`.
- Deploy command on this machine: `home-manager switch --flake ~/nixos-config#weijie_huang@devbox-7700`
- SKILL.md files must contain **no personal paths** (no `~/nixos-config`, no `weijie_huang`) except the standardized `~/.claude/feedback/` tree. Tier-2 location comes from the config file.
- Skills land in `skills/<name>/SKILL.md` at repo root — auto-symlinked to `~/.claude/skills/<name>` on switch (existing wiring in `home/claude-code.nix`, no edits needed for that).
- Rule files land in `home/claude-rules/` — always injected via existing `rulesDir` wiring.
- Phase 1 scope: global instance only. `kind: domain` feedback routes to per-project memory, not the WAL. No staged tier, no tier 3, no promotion.
- WAL invariants: `wal.md` is append-only (only `/synthesize-rules` compaction may rewrite it); IDs are `R###`, monotonically increasing; `active-rules.md` holds one line per rule, no near-duplicates.
- Thresholds: synthesis suggested at ≥ 10 WAL entries, OR oldest entry ≥ 14 days old AND > 2 entries.

---

### Task 1: SessionStart injection hook

**Files:**
- Modify: `home/claude-code.nix` (let-block addition + `hooks.SessionStart`, currently line 92: `SessionStart = [ mkZellaudeHook ];`)

**Interfaces:**
- Consumes: hook stdin JSON from Claude Code with a `.cwd` field.
- Produces: files read at session start — `~/.claude/feedback/global/active-rules.md`, `~/.claude/feedback/projects/<slug>/active-rules.md`, `~/.claude/feedback/projects/<slug>/staged-rules.md` where `<slug>` = cwd with every non-alphanumeric character replaced by `-`. Tasks 3–5 write/read these exact paths.

- [ ] **Step 1: Write the script standalone for testing**

Write `/tmp/claude-feedback-inject.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")

feedback_dir="$HOME/.claude/feedback"
files=("$feedback_dir/global/active-rules.md")

if [ -n "$cwd" ]; then
  slug=$(printf '%s' "$cwd" | sed 's|[^A-Za-z0-9]|-|g')
  files+=(
    "$feedback_dir/projects/$slug/active-rules.md"
    "$feedback_dir/projects/$slug/staged-rules.md"
  )
fi

content=""
for f in "${files[@]}"; do
  if [ -s "$f" ]; then
    content="$content$(cat "$f")"$'\n\n'
  fi
done

if [ -z "$content" ]; then
  exit 0
fi

jq -n --arg c "$content" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
```

- [ ] **Step 2: Test the failure/empty cases**

Run:
```bash
mv ~/.claude/feedback /tmp/feedback-preexisting 2>/dev/null; echo '{"cwd":"/tmp"}' | bash /tmp/claude-feedback-inject.sh; echo "exit=$?"
```
Expected: no JSON output, `exit=0`.

Run: `echo '{}' | bash /tmp/claude-feedback-inject.sh; echo "exit=$?"`
Expected: no output, `exit=0` (missing cwd handled).

- [ ] **Step 3: Test the populated case**

Run:
```bash
mkdir -p ~/.claude/feedback/global
printf '# Provisional rules (from recent feedback; obey like committed rules)\n- R001: hook test rule\n' > ~/.claude/feedback/global/active-rules.md
echo '{"cwd":"/home/weijie_huang/nixos-config"}' | bash /tmp/claude-feedback-inject.sh | jq -r '.hookSpecificOutput.additionalContext'
```
Expected: the two lines of the file printed back (valid JSON envelope, content round-trips).

- [ ] **Step 4: Wire into nix**

In `home/claude-code.nix`, add to the `let` block (after `hunkPkg`, line 15):

```nix
  feedback-inject = pkgs.writeShellApplication {
    name = "claude-feedback-inject";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      input=$(cat)
      cwd=$(jq -r '.cwd // empty' <<<"$input")

      feedback_dir="$HOME/.claude/feedback"
      files=("$feedback_dir/global/active-rules.md")

      if [ -n "$cwd" ]; then
        slug=$(printf '%s' "$cwd" | sed 's|[^A-Za-z0-9]|-|g')
        files+=(
          "$feedback_dir/projects/$slug/active-rules.md"
          "$feedback_dir/projects/$slug/staged-rules.md"
        )
      fi

      content=""
      for f in "''${files[@]}"; do
        if [ -s "$f" ]; then
          content="$content$(cat "$f")"$'\n\n'
        fi
      done

      if [ -z "$content" ]; then
        exit 0
      fi

      jq -n --arg c "$content" \
        '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
    '';
  };
```

(Note the `''${files[@]}` escape — required inside nix `''` strings; all other `$` uses are literal to nix.)

Replace `SessionStart = [ mkZellaudeHook ];` in `claudeCodeSettings.hooks` with:

```nix
      SessionStart = [
        {
          matcher = "startup|clear|compact";
          hooks = [
            {
              type = "command";
              command = "${feedback-inject}/bin/claude-feedback-inject";
            }
          ];
        }
        mkZellaudeHook
      ];
```

- [ ] **Step 5: Switch and verify deployment**

Run: `home-manager switch --flake ~/nixos-config#weijie_huang@devbox-7700`
Expected: activation completes without error.

Run: `jq '.hooks.SessionStart' ~/.claude/settings.json`
Expected: array containing an entry with matcher `startup|clear|compact` and a `/nix/store/...claude-feedback-inject/bin/claude-feedback-inject` command, plus the zellaude entry.

Run the deployed script directly:
```bash
echo '{"cwd":"/tmp"}' | "$(jq -r '.hooks.SessionStart[0].hooks[0].command' ~/.claude/settings.json)" | jq -r '.hookSpecificOutput.additionalContext' | head -n 2
```
Expected: the R001 test-rule header lines from Step 3.

- [ ] **Step 6: Verify live injection end-to-end**

Run: `cd /tmp && claude -p "Do you have any provisional rules from a feedback WAL in your context? Answer yes/no and quote the rule IDs."`
Expected: answer mentions R001.

- [ ] **Step 7: Clean up test state and commit**

```bash
rm -rf ~/.claude/feedback
[ -d /tmp/feedback-preexisting ] && mv /tmp/feedback-preexisting ~/.claude/feedback
rm /tmp/claude-feedback-inject.sh
cd ~/nixos-config && git add home/claude-code.nix && nix develop -c git commit -m "$(cat <<'EOF'
add sessionstart hook injecting feedback wal rules

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Auto-trigger rule

**Files:**
- Create: `home/claude-rules/feedback-loop.md`

**Interfaces:**
- Consumes: nothing.
- Produces: an always-injected instruction referencing "the give-feedback skill" (Task 3's skill name: `give-feedback`) and the "Provisional rules" heading (exact heading written by Task 3 into `active-rules.md`).

- [ ] **Step 1: Write the rule file**

Create `home/claude-rules/feedback-loop.md`:

```markdown
# Feedback loop

When the user corrects how you work — code style, structure, tool usage,
shell habits, workflow, communication, or factual project knowledge; not
task-specific bug reports — invoke the give-feedback skill after addressing
the correction, even if the user did not invoke it explicitly.

Provisional rules injected at session start (under a "Provisional rules"
heading) are binding, the same as committed rules.

Never proactively solicit feedback.
```

- [ ] **Step 2: Switch and verify injection**

Run: `home-manager switch --flake ~/nixos-config#weijie_huang@devbox-7700`
Expected: completes without error.

Run: `cd /tmp && claude -p "Do your instructions say anything about invoking a skill when the user corrects how you work? Quote the relevant sentence."`
Expected: response quotes the feedback-loop rule.

- [ ] **Step 3: Commit**

```bash
cd ~/nixos-config && git add home/claude-rules/feedback-loop.md && nix develop -c git commit -m "$(cat <<'EOF'
add feedback-loop auto-trigger rule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: /give-feedback skill

**Files:**
- Create: `skills/give-feedback/SKILL.md`

**Interfaces:**
- Consumes: `~/.claude/feedback/global/config.md` (scaffolds via wizard if absent).
- Produces: `~/.claude/feedback/global/wal.md` entry blocks and `~/.claude/feedback/global/active-rules.md` lines in the exact formats below — Task 4's audit step validates against these formats verbatim.

- [ ] **Step 1: Write the skill**

Create `skills/give-feedback/SKILL.md`:

````markdown
---
name: give-feedback
description: Capture corrections about how you work — code style, workflow, tool usage, environment quirks, project knowledge. Fix the current work, generalize the feedback into provisional rules, and append them to the feedback WAL. Use whenever the user corrects your output or behavior, even without an explicit /give-feedback invocation.
---

# Give Feedback

Turns corrections into provisional rules that take effect next session, and
into evidence that /synthesize-rules later compacts into permanent rules.

Pipeline, in order, none optional: load config → collect → fix → generalize
→ sanity-check → write → threshold check → report.

## Load config

Read `~/.claude/feedback/global/config.md`. If missing, run the setup
wizard (end of this skill) first.

## Collect

Gather every piece of correction-style feedback from this conversation not
already logged: the invocation arguments plus corrections given organically
earlier. Correction-style = guidance about how you work. "This test fails"
is a bug report, not feedback; "stop writing tests that duplicate coverage"
is feedback.

## Fix

Apply the feedback to the current work first when there is something to
apply it to (a changeset to amend, a command to redo). Implementing the fix
grounds the generalization. Pure behavioral corrections skip this step.

## Generalize

Cluster the feedback — corrections of the same issue in different places
are one cluster. Draft one candidate rule per cluster: 1–2 lines, phrased
as a general instruction, not a description of today's incident.

Tag each cluster with a kind:

- code-style — how the artifact should look: naming, comments, structure,
  error handling, test shape.
- workflow — how you go about work: process, verification habits, tool
  choice, git conventions, communication.
- environment — constraints of the user's machines or toolchain that make
  commands succeed or fail, as opposed to preferences.
- domain — knowledge about a specific codebase or system, true no matter
  who is coding: architecture, data shapes, subsystem gotchas.

Only the domain boundary changes behavior (litmus: a fact about a codebase,
not about how you work). Kind records origin, not reach — an environment
correction may still yield a globally valid rule. Also record a scope hint:
general, a language, a purpose (e.g. perf), or a host, when the feedback is
clearly narrower than everything.

## Sanity check

Cheap and in-context only — no repo scanning:

- Contradiction scan: does a candidate contradict a committed rule or an
  injected provisional/staged rule? Surface it to the user now and ask
  which wins; never log a contradiction silently. A correction that
  contradicts a staged rule is logged as negative evidence naming that
  rule.
- Generalizability: a plausible one-off is logged as evidence-only (WAL
  entry, no active-rules line) so synthesis can spot a pattern later.

## Write

Routing: domain-kind clusters do not go to this WAL — store them in the
session's project memory if available, otherwise tell the user. Everything
else goes to the global instance.

Append one block per cluster to `~/.claude/feedback/global/wal.md`
(create with a `# Feedback WAL` first line if missing). The WAL is
append-only: never edit or merge existing blocks. If an existing entry
covers similar ground, reference it in relates-to instead. ID = next
integer after the highest R### in the file.

    ## R014 — <short title>
    created: <YYYY-MM-DD> | kind: <kind> | scope: <scope hint>
    relates-to: <comma-separated R###, or —>
    rule: <the 1–2 line candidate rule>
    instances:
    - <YYYY-MM-DD> <repo or project>: "<user's words, condensed>" — <what
      the fix changed, one line>

Then update `~/.claude/feedback/global/active-rules.md` (create with
exactly this header line if missing):

    # Provisional rules (from recent feedback; obey like committed rules)
    - R014: <rule text>

One line per generalizable rule, rule text only — this file is injected
into every session and every token costs. Skip the line if an equivalent
one already exists; the WAL evidence is enough.

## Threshold check

Count `## R` entries and read the oldest `created:` date in `wal.md`. If
entries >= 10, or the oldest is >= 14 days old and entries > 2, tell the
user: "The feedback WAL is ripe (<N> entries, oldest <date>) — run
/synthesize-rules in a fresh session."

## Report

One or two lines: what was fixed, what was logged (IDs + rule text), any
threshold notice.

## Setup wizard (first run only)

Runs when `~/.claude/feedback/global/config.md` is missing:

1. Confirm scope with the user: global — applies to them across all repos.
2. Ask where their curated rules live (tier 2): a rules directory managed
   in a dotfiles repo (ask for the path), or sections in
   `~/.claude/CLAUDE.md`.
3. Write `~/.claude/feedback/global/config.md`:

       # Feedback loop config — global instance
       scope: global
       wal: ~/.claude/feedback/global/
       tiers:
         1. WAL + active-rules.md, injected at session start
         2. <their answer> (curated; final tier)

4. Check wiring: if no SessionStart hook in their Claude settings reads
   `~/.claude/feedback/`, print the hook command or settings snippet they
   need and where to add it. Do not edit their settings yourself.
````

- [ ] **Step 2: Deploy and verify the skill loads**

Run: `home-manager switch --flake ~/nixos-config#weijie_huang@devbox-7700`
Run: `head -n 4 ~/.claude/skills/give-feedback/SKILL.md`
Expected: the frontmatter above.

- [ ] **Step 3: Dry-run the wizard + capture path**

Preserve any real WAL state, then run a scripted session:

```bash
mv ~/.claude/feedback /tmp/feedback-real 2>/dev/null || true
cd /tmp && claude -p "/give-feedback Two corrections from my review: (1) in the Go changeset you wrapped every error with a message restating the function name — in internal/store/user.go, internal/store/org.go, and internal/api/handler.go; don't do that, the wrap should add context the caller lacks. (2) you ran 'grep -r' to find the callers of a renamed method; use ast-grep for rename verification instead. There is no live changeset to fix, just log these. For the setup wizard: tier 2 is the rules directory home/claude-rules in my dotfiles repo at ~/nixos-config."
```
Expected: the run reports logging (not fixing, since no changeset), and mentions two rules.

- [ ] **Step 4: Validate produced files against the format**

```bash
cat ~/.claude/feedback/global/config.md
cat ~/.claude/feedback/global/wal.md
cat ~/.claude/feedback/global/active-rules.md
```
Expected, checked line by line:
- `config.md` has `scope: global` and a tier 2 naming `home/claude-rules`.
- `wal.md` starts `# Feedback WAL`; exactly 2 entry blocks `## R001`/`## R002` (the three same-issue error-wrap corrections deduped into ONE cluster); each block has `created:`/`kind:`/`scope:` on one line, `relates-to:`, `rule:`, and at least one `instances:` bullet. Error-wrap entry is `kind: code-style`; ast-grep entry is `kind: workflow`.
- `active-rules.md` line 1 is exactly `# Provisional rules (from recent feedback; obey like committed rules)`, followed by `- R001: ...` and `- R002: ...`.

If any check fails: fix the skill text (the instruction the agent misread), rerun Steps 3–4 after `rm -rf ~/.claude/feedback`.

- [ ] **Step 5: Verify the capture round-trips through injection**

Run: `cd /tmp && claude -p "List the IDs and texts of any provisional rules in your context."`
Expected: R001 and R002 quoted.

- [ ] **Step 6: Verify contradiction surfacing**

The user's committed bash rules say to use `~` instead of `$HOME`. Feed the
opposite as feedback:

```bash
cd /tmp && claude -p "/give-feedback From now on always write \$HOME instead of ~ in shell commands."
```
Expected: the run flags that this contradicts a committed rule and asks
which wins, instead of silently appending a WAL entry. Verify no new entry:
`grep -c '^## R' ~/.claude/feedback/global/wal.md` still prints `2`.

If it logged silently: tighten the Sanity check section wording in
SKILL.md and rerun this step after deleting the bad entry.

- [ ] **Step 7: Clean up and commit**

```bash
rm -rf ~/.claude/feedback
[ -d /tmp/feedback-real ] && mv /tmp/feedback-real ~/.claude/feedback
cd ~/nixos-config && git add skills/give-feedback && nix develop -c git commit -m "$(cat <<'EOF'
add give-feedback capture skill

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: /synthesize-rules skill

**Files:**
- Create: `skills/synthesize-rules/SKILL.md`

**Interfaces:**
- Consumes: `config.md`, `wal.md`, `active-rules.md` in the Task 3 formats; the tier-2 store named by config.
- Produces: rewritten tier-2 rules files + compacted WAL; an audit report with resolution-vs-process defect classification.

- [ ] **Step 1: Write the skill**

Create `skills/synthesize-rules/SKILL.md`:

````markdown
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

Classify each defect: resolution error (capture failed to follow the
config — wrong path, wrong instance, wrong destination) vs process error
(a skipped step, e.g. missed dedupe). Report both counts to the user —
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
  always-injected rules file so it loads reliably
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
the repos the rule targets. Check: (a) the rule would not flag reasonable
existing code — the false-positive test; (b) the instances genuinely
support the generalization rather than one incident phrased twice. Demote
failures to carry-forward or drop, and say why.

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
````

- [ ] **Step 2: Deploy and verify the skill loads**

Run: `home-manager switch --flake ~/nixos-config#weijie_huang@devbox-7700`
Run: `head -n 4 ~/.claude/skills/synthesize-rules/SKILL.md`
Expected: the frontmatter above.

- [ ] **Step 3: Fabricate a WAL with planted defects**

```bash
mv ~/.claude/feedback /tmp/feedback-real 2>/dev/null || true
mkdir -p ~/.claude/feedback/global
cat > ~/.claude/feedback/global/config.md <<'EOF'
# Feedback loop config — global instance
scope: global
wal: ~/.claude/feedback/global/
tiers:
  1. WAL + active-rules.md, injected at session start
  2. home/claude-rules/ in the dotfiles repo at ~/nixos-config (curated; final tier)
EOF
cat > ~/.claude/feedback/global/wal.md <<'EOF'
# Feedback WAL

## R001 — errors wrapped with function-name restatement
created: 2026-06-01 | kind: code-style | scope: go, general?
relates-to: —
rule: Error wraps must add context the caller lacks, not restate the function name.
instances:
- 2026-06-01 analytics: "every fmt.Errorf repeats the func name" — removed 6 redundant prefixes

## R002 — same issue again in another repo
created: 2026-06-20 | kind: code-style | scope: general
relates-to: R001
rule: Error wraps must add context the caller lacks.
instances:
- 2026-06-20 nixos-config: "again with the redundant wrap messages" — reworded 2 wraps

## R003 — DQS fans out queries across LQS pods
created: 2026-06-21 | kind: domain | scope: analytics
relates-to: —
rule: DQS fans out queries across LQS pods; merging happens in dqs/query.
instances:
- 2026-06-21 analytics: "that's dqs's job, not lqs" — n/a

## R004 — used head -15 on devbox
created: 2026-06-22 | kind: environment
rule: Use head -n N; the short form head -N is unsupported on some hosts.
instances:
- 2026-06-22 analytics: "head -15 failed again" — reran with head -n 15
EOF
cat > ~/.claude/feedback/global/active-rules.md <<'EOF'
# Provisional rules (from recent feedback; obey like committed rules)
- R001: Error wraps must add context the caller lacks, not restate the function name.
- R002: Error wraps must add context the caller lacks.
- R004: Use head -n N; the short form head -N is unsupported on some hosts.
EOF
```

Planted defects: R003 is a domain entry in the global WAL (resolution error); R004 is missing `scope:` (process error); R001/R002 are near-duplicate active-rules lines (process error).

- [ ] **Step 4: Dry-run synthesis up to the review gate**

Run:
```bash
cd ~/nixos-config && claude -p "/synthesize-rules Run the full flow but STOP after presenting the diff for review (step 6) — do not commit and do not compact the WAL. End your output with the audit defect counts on a line formatted exactly: AUDIT resolution=<n> process=<n>"
```
Expected in the output:
- Audit reports R003 as wrong-instance (resolution error ≥ 1) and the R004 missing scope + R001/R002 near-duplicate lines as process errors (process ≥ 2).
- R001+R002 clustered into one candidate rule targeting `home/claude-rules/` (code-style file or new).
- R004 kept in its already-portable phrasing.
- R003 routed out (not into global rules) — flagged for project memory/loop.
- A false-positive evaluation mentioning real code sampled from at least one repo.
- A diff touching only `home/claude-rules/` files, presented but NOT committed.

Run: `git -C ~/nixos-config status --porcelain -- home/claude-rules` — any modifications shown must be restorable; run `git -C ~/nixos-config checkout -- home/claude-rules` to discard.

- [ ] **Step 5: Verify the WAL was not compacted**

Run: `grep -c '^## R' ~/.claude/feedback/global/wal.md`
Expected: `4` (dry run must not rewrite the WAL).

If any expectation in Steps 4–5 fails: tighten the corresponding instruction in SKILL.md and rerun from Step 3 (recreate the fixture files).

- [ ] **Step 6: Clean up and commit**

```bash
rm -rf ~/.claude/feedback
[ -d /tmp/feedback-real ] && mv /tmp/feedback-real ~/.claude/feedback
cd ~/nixos-config && git add skills/synthesize-rules && nix develop -c git commit -m "$(cat <<'EOF'
add synthesize-rules compaction skill

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: End-to-end smoke test

**Files:**
- None created; exercises Tasks 1–4 together.

**Interfaces:**
- Consumes: everything above, deployed.

- [ ] **Step 1: Organic-feedback trigger test**

With no `~/.claude/feedback` dir present (`mv ~/.claude/feedback /tmp/feedback-real 2>/dev/null || true`):

```bash
cd /tmp && claude -p "You are mid-task. I'm giving you feedback without naming any skill: from now on, never use 'git add -A'; stage files explicitly. Handle this the way your instructions tell you to handle corrections. For any setup questions: tier 2 is the rules directory home/claude-rules in my dotfiles repo at ~/nixos-config." --permission-mode acceptEdits
```
Expected: the transcript shows the give-feedback skill was invoked (auto-trigger rule working) and the run reports logging one rule.

- [ ] **Step 2: Verify persistence + injection**

```bash
grep -n 'git add' ~/.claude/feedback/global/wal.md
cd /tmp && claude -p "List the IDs and texts of any provisional rules in your context."
```
Expected: the WAL contains the staging rule; the second session quotes it back with its R-ID.

- [ ] **Step 3: Restore real state**

```bash
rm -rf ~/.claude/feedback
[ -d /tmp/feedback-real ] && mv /tmp/feedback-real ~/.claude/feedback
```
(If you want to keep the `git add -A` rule for real, skip the `rm` and delete only if it was fixture noise — it is a genuine rule; keeping it is reasonable. Ask the user.)

- [ ] **Step 4: Final commit of any stragglers**

Run: `git -C ~/nixos-config status --porcelain`
Expected: clean (all work committed in Tasks 1–4). If docs changed, commit:

```bash
cd ~/nixos-config && git add -u && nix develop -c git commit -m "$(cat <<'EOF'
feedback loop phase 1 finishing touches

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```
