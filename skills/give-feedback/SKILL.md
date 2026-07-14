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

Append one block per cluster with the bundled script (path relative to
this skill's directory); it owns ID assignment, the created date, and
formatting, and prints the assigned R### ID:

    scripts/wal-append.sh --title "<short title>" --kind <kind> \
      --scope "<scope hint>" --rule "<the 1–2 line candidate rule>" \
      --instance '<YYYY-MM-DD> <repo>: "<user words, condensed>" — <what the fix changed, one line>'

The WAL is append-only: never edit or merge existing blocks by hand. If
an existing entry covers similar ground, link it with
`--relates-to "R012, R013"` instead. Repeat `--instance` for multiple
occurrences in one cluster.

Pass `--active` when the rule is generalizable and no equivalent line
already exists in `~/.claude/feedback/global/active-rules.md` — that also
appends the one-line `- R###: <rule>` to the injected file. Evidence-only
entries (plausible one-offs, violations of already-committed rules) omit
it: active-rules.md is injected into every session and every token costs.

The resulting formats, which /synthesize-rules audits against:

    ## R014 — <short title>
    created: <YYYY-MM-DD> | kind: <kind> | scope: <scope hint>
    relates-to: <comma-separated R###, or —>
    rule: <the 1–2 line candidate rule>
    instances:
    - <YYYY-MM-DD> <repo or project>: "<user's words, condensed>" — <what
      the fix changed, one line>

    # Provisional rules (from recent feedback; obey like committed rules)
    - R014: <rule text>

## Threshold check

Count `## R` entries and read the oldest `created:` date in `wal.md`. If
entries >= 20, or the oldest is >= 14 days old and entries > 2, tell the
user: "The feedback WAL is ripe (<N> entries, oldest <date>) — run
/synthesize-rules in a fresh session."

## Report

One or two lines: what was fixed, what was logged (IDs + rule text), any
threshold notice.

## Setup wizard (first run only)

Runs when `~/.claude/feedback/global/config.md` is missing:

1.  Confirm scope with the user: global — applies to them across all repos.
2.  Ask where their curated rules live (tier 2): a rules directory managed
    in a dotfiles repo (ask for the path), or sections in
    `~/.claude/CLAUDE.md`.
3.  If tier 2 is a repo-managed rules directory, work out its promotion
    protocol — how an edited rule reaches a live session — by reading the
    repo, never by assuming:
    - How files deploy: inspect the config that installs them (e.g. a
      home-manager module). Record whether the whole directory is enumerated
      or each file is listed individually. If you can't tell, write
      "deployment wiring unverified" rather than a plausible-sounding claim.
    - The repo's default branch, and whether promotion commits stay local
      for the user to review and deploy, or may be pushed.
4.  Write `~/.claude/feedback/global/config.md`: the header below, plus a
    "Tier 2 promotion protocol" section recording what step 3 established
    (omit that section when tier 2 is `~/.claude/CLAUDE.md`).

        # Feedback loop config — global instance
        scope: global
        wal: ~/.claude/feedback/global/
        tiers:
          1. WAL + active-rules.md, injected at session start
          2. <their answer> (curated; final tier)

5.  Check wiring: if no SessionStart hook in their Claude settings reads
    `~/.claude/feedback/`, print the hook command or settings snippet they
    need and where to add it. Do not edit their settings yourself.
