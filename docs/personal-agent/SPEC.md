# Personal Agent System — Spec

*North-star document. Decisions, rationale, trust model, and phased plan. Update this as reality teaches us things; treat changes to this doc like changes to code — deliberate, with a reason.*

---

## 1. Purpose

A personal assistant agent that acts like a good secretary: it holds the full breadth of my commitments, tasks, and context, and surfaces only the minimum I need at any moment. It is journal-centric (Obsidian), reachable everywhere (Telegram), aware of my email and calendar, and built so that every piece of machinery is reproducible from a Nix flake.

The system exists to compensate for ADHD-shaped failure modes: task paralysis from overwhelm, low tagging/organizing discipline, and friction at the moment of starting. Design consequences:

- **The agent holds breadth; interfaces show almost nothing.** The morning brief is calendar + ONE next action. Depth is available only on request.
- **Zero required ritual.** No streaks, no guilt, nothing that punishes an off day. Rituals that exist (weekly planning) are agent-initiated, so forgetting them costs nothing.
- **Friction-free capture.** Appending to the journal or messaging Telegram is always enough. Organizing is the agent's job.
- **Next actions are atomic.** "Email Sarah for the project files," never "organize project."

## 2. Principles

1. **Declarative machinery, versioned state.** Everything that can be pure config lives in the Nix flake (server, services, MCP servers, bot, vault sync; secrets are the one documented exception, decision 18). Data that is inherently state (vault content, agent memory) is versioned in git so it is diffable, reviewable, and revertible — the closest honest analogue to declarative for mutable data.
2. **Minimal and lightweight.** No Linear/ClickUp. Tasks are markdown in the vault. Prefer deleting a component to configuring it.
3. **Graceful degradation.** If the agent/server is down: Obsidian still works on every device (sync runs through Obsidian's servers, not the hub), tasks are native checkboxes in the Obsidian app, calendar is still Google Calendar. The agent is an enhancement layer, never a single point of failure for my own data.
4. **Trust is earned incrementally.** Start read-only / propose-first everywhere it's cheap to, loosen deliberately. Every agent write is a git commit with a meaningful message.
5. **Assume prompt injection.** Email and web content are untrusted input. The blast radius of a malicious email must be bounded by construction (scoped tokens, isolated credential-holding services, no autonomous email sending, approval-gated skill creation).

## 3. Architecture

```
                        ┌─────────────────────────────────────────┐
                        │  NixOS VPS (the hub, one flake)          │
                        │                                          │
  Android phone         │  ┌──────────┐   ┌──────────────────┐    │
  ├ Obsidian app        │  │ Hermes    │──▶│ Telegram bridge  │◀──┼──▶ me, anywhere
  └ Obsidian Sync ──────┼─▶│ (Claude   │   └──────────────────┘    │
                        │  │  as model)│   ┌──────────────────┐    │
                        │  └────┬─────┘──▶│ Fastmail MCP      │───┼──▶ JMAP (read-only,
  Framework 16          │       │         │ (isolated svc,    │    │    label-filtered)
  ├ Obsidian (Windows)  │       │         │  owns the token)  │    │
  ├ Obsidian Sync ──────┼───────┼──┐      └──────────────────┘    │
  │  (vault on NTFS)    │       │  │      ┌──────────────────┐    │
  └ WSL: NixOS (tinker),│       │  │      │ GCal MCP (r/w)    │───┼──▶ Google Calendar
     dev + git (config) │       ▼  ▼      └──────────────────┘    │
                        │  ┌──────────┐   ┌──────────────────┐    │
                        │  │ Vault     │   │ systemd timers:   │    │
                        │  │ (ob sync  │   │ brief, distill,   │    │
                        │  │ +git hist)│   │ snapshot, planning│    │
                        │  └──────────┘   └──────────────────┘    │
                        └─────────────────────────────────────────┘
```

**Hub:** small NixOS VPS (Hetzner-class, ~2 vCPU / 4 GB is plenty; agent work is token-bound, sync + bot are featherweight). Entire box is one flake: the sync client, systemd services + timers, MCP servers, Hermes, Telegram bridge, secrets out of band (decision 18). Rebuildable from scratch with one install command plus a documented secret-restore step; the vault itself needs no restore, since re-linking the sync client pulls it back from Obsidian's servers. Its git history exists only on the hub and starts fresh.

**Agent runtime:** Hermes (Nous Research) as the harness — messaging-first, persistent memory, cron, skills — wrapping Claude via AnthropicTransport. Provider-agnostic by construction; the model is config, not architecture. Hardening (see §6): Telegram gateway only, user-ID allowlisted; skill creation disabled or approval-gated initially.

**Interfaces, in order of expected use:** Telegram (capture, queries, briefs, approvals) → Obsidian app (reading, writing, native task checkboxes) → SSH to the hub (escape hatch).

### Repo integration: builds inside `weiijiie/nixos-config`

The hub is a new host in my existing flake, not a standalone repo:

- **Host:** `nixosConfigurations.io` via the existing `mkHost` helper + a `hosts/io/` dir. Inherits overlays (`unstable`, `scripts`, `custom`, `llm-agents`) and `home/common.nix` with the package list slimmed to essentials (decision 20): the hub is an appliance, deploys come from tinker, and dev work belongs on a devbox. Remote deploy: `nixos-rebuild switch --target-host`, identical on either platform. First install is the one platform-specific step: `nixos-anywhere` against `hosts/io/disko.nix` on a conventional VPS, or the OCI image from `pkgs/io-image.nix` with `hosts/io/oci.nix` on exe.dev (decision 17b).
- **Agent services:** `modules/nixos/agent/{hermes.nix,fastmail-mcp.nix,gcal-mcp.nix,timers.nix}`, following the exported-`nixosModules` pattern. Broken agent modules can't affect other hosts unless imported; flake checks catch eval errors across all hosts on every change.
- **Custom code:** label-filtering Fastmail MCP wrapper as a `pkgs/` entry. Hermes packaged in `pkgs/` too if not already in the `llm-agents.nix` overlay (check at impl time).
- **Vault modules:** `modules/nixos/vault-sync.nix` declares the vault's path and owner and the hub's Obsidian Sync client with its settings. Its sibling `modules/nixos/vault-git.nix` owns the server-side history layer (repo + snapshot timer), which is vault machinery rather than agent machinery and so sits outside `modules/nixos/agent/`. Devices are set up by hand in the Obsidian app.
- **Secrets:** deployed out of band, not committed in any form (decision 18). Revisit in Phase 1, when the first credential actually exists.
- **Stays OUT of the repo:** vault content (Obsidian Sync + hub-side git per §4), Obsidian settings (synced between devices by Obsidian Sync), Hermes runtime state, all secrets material. AGENTS.md lives in the vault (the agent needs it in context and it evolves conversationally).

## 4. Vault sync design

Diagram: [Obsidian Sync on the hub](https://claude.ai/code/artifact/e20f570e-e4e2-4410-9b1c-32d30e2270c8).
Findings behind this design are in `docs/personal-agent/OB-TRIAL.md`.

Two cleanly separated layers:

**Content — Obsidian Sync.** Phone, laptop and hub sync one end-to-end encrypted remote vault (`Observer`). The devices use the Obsidian app's built-in sync. The hub runs the official headless client (`ob sync --continuous`) as the `vault-sync` unit from `modules/nixos/vault-sync.nix`, which also declares its settings and reapplies them at every start. Every connection is outbound to Obsidian's servers, so the hub needs no inbound port for sync.

- The hub syncs notes and every attachment type, including the `unsupported` category, which is off by default. Types outside the default four would otherwise be dropped without an error.
- Files over the plan's size ceiling are refused, also without an error: 5 MB on Standard, 200 MB on Plus. The hub never receives them, so a note can link to an attachment the agent cannot read.
- Dot-prefixed paths never sync, so `.git` and `.gitignore` stay on the hub with no exclusion config.
- The login token never expires on its own and is never refreshed. A revoked token (password change, sign-out everywhere) or a lapsed subscription leaves `vault-sync` retry-looping with nothing surfaced, so the staleness check (§9) watches the hub's own sync.

**History — git, server-side only.** On the hub, the vault directory is also a git repo (gitignoring `.obsidian/`). A systemd timer snapshots human edits (`human edits @ <timestamp>`); the agent commits its own edits with meaningful messages. This is the review/rollback layer: every agent change is a diff I can inspect from Telegram or revert. Devices never see this repo. Obsidian Sync keeps its own per-file version history, but only the app can reach it, so this layer is the hub's only audit trail.

**Obsidian config — Sync's settings categories.** Devices share settings, hotkeys, themes, snippets and plugins through Obsidian Sync's opt-in config categories, and plugin code travels with them, so every device runs the same plugin versions. The hub turns every category off, since it runs no editor. Each category syncs whole: a plugin's `data.json` travels with its code, and `graph.json` with every other core-plugin setting, so neither can be kept per-device on its own. Per-device window layout (`workspace.json`, `workspace-mobile.json`) never syncs.

**Conflict handling:** concurrent edits merge by character position (the `merge` strategy). There are no conflict copies and nothing is lost, but two edits at the same spot interleave mid-sentence. The agent therefore writes to its own file regions (§5), and git history on the hub shows both sides of a jumbled merge.

### Laptop design: Windows-side everything (decided)

On the Framework, Obsidian runs on **Windows** and the vault lives on **NTFS**, synced by the app itself. Rationale — the three options considered:

1. *Obsidian on Windows, vault in WSL:* ruled out. Windows watches WSL files over the 9P bridge, and change notifications don't propagate reliably — a sync process in WSL writing an incoming phone edit would leave Windows Obsidian showing stale content until a rescan. Exactly our write pattern; worst option.
2. *Obsidian in WSLg, vault on Linux FS:* the nix-pure option (everything in the tinker flake, correct inotify). Viable fallback, but WSLg Electron papercuts (rendering, `obsidian://` links from Windows browsers, tray) make it second choice.
3. *All-Windows (chosen):* native Obsidian UX, correct same-FS file watching. Laptop sync does not depend on WSL being awake at all.

**Rule of thumb that survives the decision:** never put the vault behind 9P in either direction — the watcher and the files must live on the same OS. WSL (tinker) can still read the vault at `/mnt/c/...` for CLI/claude-code work; slow but fine for markdown. Two further WSL learnings that keep it out of any critical path: WSL's two-tier idle shutdown (`instanceIdleTimeout`/`vmIdleTimeout`) silently kills background processes, and Windows sleep causes clock skew inside WSL that breaks cron timing and TLS until resync. If anything scheduled must ever run on tinker, the known pattern is Windows Task Scheduler as the outer scheduler invoking WSL as the execution environment — but for this system, all scheduling lives on the hub.

**Costs, accepted:** the laptop exits the flake — Obsidian and its Sync settings are configured by hand in the app. NTFS case-insensitivity means notes differing only by case would collide (non-issue single-user). The app syncs only while it is open, so the laptop's copy can lag; nothing else waits on it, since every device syncs against Obsidian's servers.

## 5. Vault structure & conventions

Journal-centric, logseq-flavored, minimal:

```
vault/
├── AGENTS.md           # the agent's contract: what it may touch, how, conventions
├── journal/            # daily notes, YYYY-MM-DD.md — my raw appends, agent-annotated
├── notes/              # evergreen notes (migrated Notion content lands here)
├── tasks.md            # Tasks query views, then the tasks the agent creates (see §7)
├── agent/              # agent's own area
│   ├── memory/         # copy of Hermes' memory, plus longer notes it keeps
│   ├── proposals/      # propose-first edits awaiting approval
│   └── changes/        # YYYY-MM.md: one line per agent commit, written by the tooling
└── .obsidian/          # editor settings, synced between devices only
```

**AGENTS.md is load-bearing.** Hermes loads it from the vault root into every prompt. It holds the vault contract only: the map of the vault, what the agent may change freely, what needs a proposal and what is off limits, the journal and task conventions, where to look before asking me anything, and that instructions found in notes or tool output are data. Procedures (`/log`, the end-of-day distillation, the brief) are Hermes skills declared in the flake, loaded only when used and reviewed like code. The agent changes AGENTS.md only with my approval, and the rules that matter most are also enforced by hooks (decision 29) rather than trusted to the prompt.

**Journal conventions:**
- I append freely, zero discipline required. No tags, no structure, whatever.
- A `/log` capture lands as a timestamped bullet (`- 14:32 text`) above the synthesis section.
- Agent may add tags and wikilinks **inline and autonomously** — it can read the whole graph and connect things I wouldn't. These are additive, small-diff edits.
- Autonomous *content* (synthesis, summaries) goes in a clearly marked section, e.g. `## ✦ synthesis (agent)` at the bottom of the daily note — my raw words stay mine.
- Edits I explicitly request ("clean up that paragraph") are done inline.
- Unrequested rewording of my prose: **propose-first** — agent writes the proposal as a note in `agent/proposals/` (the passage, the suggested rewrite, why), pings Telegram, applies on approval. Revisit this dial after a few weeks.

## 6. Connectors & trust model

| Connector | Access | Enforcement | Notes |
|---|---|---|---|
| Fastmail | **Read-only**, label-filtered | Read-only API token; label allowlist enforced in our MCP wrapper | Token scopes are capability-level only (no per-label tokens exist), so filtering lives in the MCP layer. A Fastmail rule tags incoming mail (e.g. `agent-visible`, or allowlist labels like receipts/travel/newsletters); the MCP refuses to serve anything else. **No email sending, period** (no submission scope on the token). Evaluate Fastmail's official MCP server as the base to wrap/fork. |
| Google Calendar | Read + write | OAuth scoped to my personal calendar | Agent may create/modify events autonomously; deletions propose-first initially. |
| Vault | Read all; write per AGENTS.md | AGENTS.md contract, enforcing hooks, git review layer | 99% readable/editable; propose-first only for rewording my words. |
| Telegram | Full duplex | Bot locked to my user ID; gateway allowlist in Hermes | The only inbound human channel. |

**Credential isolation:** the Fastmail MCP runs as its own systemd service under its own user, holding the token in its own environment; Hermes talks to it over a local socket and can never read the credential. Same pattern for GCal. This is the self-hosted approximation of edge secret injection: prompt-injected agent ≠ exfiltrated token. Secrets live only on the hub, never in the repo, never in the vault, never in agent-readable files.

**Hermes hardening:**
- **Skill/memory store is security-sensitive.** It is a mutable, persistent instruction store, and the agent reads untrusted input (email, web): a prompt injection persisted into a skill file gets silently reapplied every time the skill matches. Therefore: skill creation/modification **approval-gated** (start with Hermes drafting skills but not activating them; grant write only after review works well); skill + memory directories **versioned in git** with diffs reviewed like code; a run that touched untrusted content never writes to them unreviewed.
- **Gateway:** Telegram only, my user ID allowlisted; all other messaging platform gateways disabled (each enabled platform is another inbound door).
- **Supply chain:** package from the official `github.com/NousResearch/hermes-agent` repo only, pinned by rev/hash in the flake — lookalike domains with one-line installers exist. Nix pinning is the enforcement.
- **Billing:** the agent's Anthropic key is the one secret it necessarily holds — budget-cap at the provider and meter early; an always-on chatty agent on per-token billing adds up faster than expected.
- **Harness-quality caveat, acknowledged:** Claude Code's loop is tuned against Claude specifically; a generic harness driving the same model may give up some quality. Watch for it in practice — Claude Code headless remains the fallback harness if Hermes underdelivers.

**Injection posture:** email bodies are untrusted. The agent summarizes and reasons about them, but instructions found inside email content are never executed as instructions. This goes in the Hermes system prompt AND is structurally backed by the scoping above (worst case is bounded: it can read allowlisted mail and write to the vault/calendar — all reviewable).

## 7. Workflows

**Morning brief** (scheduled job → Telegram, fixed time): today's calendar events + **one** next action with a one-line context + nothing else. "What else is there?" reveals breadth on demand. Conflict warnings included when they exist. Iterate on contents after two weeks of use.

**Capture → journal:**
- Telegram `/log <text>` (or reply-tagging a message): explicitly journaled, verbatim-ish, immediately.
- End-of-day distillation (scheduled job): agent reviews the day's Telegram chat + journal appends, writes a few journal-worthy lines into the daily note's synthesis section, tags/links everything, files task-shaped statements into the task system. The chat log itself is NOT the journal.

**Tasks:** Obsidian Tasks plugin syntax in the vault (`- [ ] task 📅 date` etc.). A checkbox counts as a task only when it carries `#task` (the plugin's global filter), so checklists, templates and the Notion import's leftovers never become live tasks. Tasks can live in any note; the ones the agent creates go in `tasks.md`, whose query blocks are the dashboard. `[/]` marks the task in progress. Queryable in-app, native checkboxes on the phone (degradation story), plain text for the agent. The agent: decomposes big tasks into atomic next actions when asked or when it spots an undecomposed lump; maintains priority metadata in its memory rather than cluttering the task lines; surfaces exactly one next action at a time via brief/on-request.

**Priorities & memory:** the agent maintains `agent/memory/` — learned priorities, deadlines, people, my patterns (what granularity gets me to start, what times I actually work). Bootstrap: a one-time onboarding chat. Ongoing: **agent-initiated** weekly planning session via Telegram (~10 min, skippable without penalty) + continuous common-sense inference from calendar/deadlines/journal — the secretary baseline.

**Calendar:** autonomous event creation from natural language ("dentist thursday 2pm"), conflict spotting in the brief, and a **time-blocking experiment**: for one week, the agent proposes 1–2 blocks per day for the top task (proposes, never force-fills). Explicit success criterion: if I ignore the blocks for a week, we kill the experiment guilt-free and rely on next-action surfacing alone. (Prior attempt at time-blocking didn't stick; this is a bounded retry, not a commitment.)

**Notion migration:** export from Notion → Obsidian's official Notion importer → content lands in `notes/` → the agent's shakedown task: fix broken links, de-junk formatting, propose structure/tags. Good early exercise of the propose-first loop on low-stakes content.

**Flashcards (v2, deferred):** obsidian-spaced-repetition as the base; agent generates card candidates from journal/notes ("you learned X — want a card?"); review in Obsidian, possibly via Telegram later. Activate when there's something actively being learned.

## 8. Publishing & the exe.dev question — OPEN

Two exe.dev features remain genuinely attractive: **edge secret injection** (agent structurally cannot read credentials) and **instant HTTPS + auth-proxied URLs** ("write me an HTML page and give me a link" / share-like-a-Google-Doc). Counterweights: the hub is a stateful pet, exe.dev's sweet spot is disposable VMs, and NixOS-the-distro fights their boot model — hosting the hub there surrenders the one-flake property.

Since this was written, two things were checked. exe.dev now sells a persistent VPS product ("persistent Linux VMs with HTTPS and SSH"), so the stateful-pet objection is weaker than stated above. Their VMs boot from an OCI image with the platform supplying the boot path, which `nixos-anywhere` cannot work with: it kexecs into a RAM installer and has `disko` repartition a real disk. The image route replaces it (decision 17b); their repo carries a reference NixOS configuration for exactly this, which the trial found late. Their secret handling is also better than described here: an in-VM proxy injects auth headers on outbound HTTP so the credential never exists on the VM at all, and generic HTTP-proxy integrations suggest arbitrary APIs (JMAP, Telegram) are expressible, though that was not confirmed. Note the proxy bounds exfiltration, not abuse: a prompt-injected agent that can reach the proxy can still call through it, so the Fastmail label allowlist in the MCP wrapper is still load-bearing.

Trialled for the hub; the boot contract is solved (decisions 17a, 17b, findings in `docs/personal-agent/EXEDEV-TRIAL.md`). The exe.dev repo carries a reference NixOS config, and the hub image boots to a clean `running` with day-2 updates via `nixos-rebuild --target-host`. Hub location is an open decision, and a judgement call rather than a technical one: sync needs no inbound path (decision 22).

Current position: **hub stays on the NixOS VPS.** The publishing story can be ~80% replicated declaratively: wildcard DNS on a domain + `services.caddy` with on-demand TLS + agent writes to `/var/www/<slug>/` → "make me a page" yields `https://<slug>.me.example.com` in seconds; basic-auth or OAuth2-proxy for private shares. What that does NOT replicate: edge secret injection, and the polish of exe.dev's sharing/auth UX.

Decision deferred with a concrete scoping task (Phase 2): trial exe.dev as a **satellite** — disposable sandbox VMs the agent can spin up for risky experiments, and/or the publishing surface — and check whether their integration catalog covers Fastmail/arbitrary JMAP (if edge injection can hold the email token while the hub stays on NixOS, that hybrid is genuinely interesting). If satellites become recurring, bake a custom image rather than running setup scripts (per prior evaluation: nix-the-package-manager + home-manager work fine on their Ubuntu base; NixOS-the-distro doesn't). Kill or keep after the trial.

## 9. Failure modes & degradation

| Failure | Effect | Mitigation |
|---|---|---|
| Hub down | No agent, no briefs; devices keep syncing through Obsidian's servers | Everything user-facing still works: Obsidian, native task checkboxes, GCal. Rebuild hub from flake, then re-link the sync client, which pulls the vault back. |
| Hub sync stops (token revoked, subscription lapsed, client breaks on an upgrade) | Hub copy goes stale; the unit retry-loops and nothing is surfaced | Hub-side staleness check on `vault-sync` surfaces it in the brief (§4). |
| Obsidian Sync outage | No device syncs; each keeps working on its own copy | Edits merge once service returns. Nothing to do. |
| File refused by type or size | A note links to an attachment the hub never receives; no error anywhere | Every type is enabled on the hub; the size ceiling is a plan limit (§4). |
| Concurrent edits at the same spot | Text interleaves mid-sentence; no conflict copy | Agent writes to its own file regions (§5); git history shows both sides. |
| Agent misbehaves in vault | Bad edits | Everything is a git commit; revert. Propose-first for prose. |
| Malicious email | Prompt injection | Read-only token, label allowlist, credential isolation, no sending, approval-gated skills, reviewable writes. |
| Hermes project churn | Breaking updates | Pin the version in the flake; upgrade deliberately. |

## 10. Phases & concrete tasks

### Phase 0 — Substrate (target: first weekend)
- [x] Commit this spec to `docs/personal-agent/SPEC.md` in nixos-config; add the pointer line to `CLAUDE.md` (§11). **This is the cutover step — all further work happens from Claude Code.**
- [x] Add `hosts/io` to nixos-config via `mkHost`, with `disko` for the disk layout. No secrets layer: Phase 0 needs no secret material (decision 18).
- [x] Provision the hub. Done via the exe.dev OCI image route rather than `nixos-anywhere` (decision 17b); PHASE-0 documents both provisioning routes, since the location decision is still open.
- [ ] Domain + DNS. Not blocking: exe.dev supplies a hostname with TLS and sync needs no inbound path, so this is only wanted for the publishing surface (§8).
- [x] `modules/nixos/vault-sync.nix` topology module (devices, folders, paths); hub consumes it via `services.syncthing`. Device IDs are filled in as each peer is paired. Now configures Obsidian Sync instead (decision 22).
- [x] Windows laptop: Syncthing service installed, vault at `C:\Users\h_wei\Obsidian\Vault of Souls` (moved out of OneDrive: two sync engines on one directory invite placeholder and conflict-artifact trouble), paired over the tailnet. Sync cannot depend on WSL by construction (Windows-native service, NTFS path); an explicit WSL-stopped spot check is still worth doing casually. Syncthing retired by decision 22.
- [x] Android: Syncthing-Fork paired over the tailnet; Obsidian opens the synced vault. Syncthing retired by decision 22.
- [x] Server-side vault git repo + snapshot timer (`modules/nixos/vault-git.nix`).
- [x] Acceptance test: phone edit reached hub and laptop, and snapshot `c810573` carries the diff. Ran with WSL up; see the laptop item for the WSL-stopped caveat.

### Phase 1 — Agent core (target: end of week 2; **the habit loop ships here**)
- [ ] Vault skeleton per §5; write AGENTS.md v1.
- [ ] Hermes on hub (pinned in flake), Claude transport, Telegram gateway locked to my user ID; skills approval-gated.
- [ ] `/log` capture → daily note.
- [ ] End-of-day distillation job (chat + journal → synthesis section + tags/links + task extraction).
- [ ] Morning brief job (calendar comes in Phase 2; brief starts as next-action-only).
- [ ] Onboarding chat → seed `agent/memory/`.
- [ ] **Success criterion: I am using Telegram capture and reading the brief daily by end of week 2.**

### Phase 2 — Senses (weeks 3–4)
- [ ] GCal MCP (isolated service), events in brief, natural-language event creation, conflict spotting.
- [ ] Fastmail: create `agent-visible` labeling rules; read-only token; deploy label-filtering MCP as isolated service (evaluate official Fastmail MCP as base). Email context flows into briefs/queries.
- [ ] Propose-first loop end-to-end: proposal → Telegram ping → approve → merge commit.
- [ ] Notion export + import + agent cleanup shakedown.
- [ ] Weekly planning session: agent-initiated, first run.
- [x] Scope exe.dev satellite (§8); boot solved for the hub (decisions 17a, 17b, 18a; findings in `docs/personal-agent/EXEDEV-TRIAL.md`). Hub location pending the vault-sync ingress test; still open as a *satellite* for disposable sandboxes.
- [ ] Publishing v0 if exe.dev is a no: caddy + wildcard subdomain + `/var/www` convention.

### Phase 3 — The secretary gets good (ongoing)
- [ ] Task decomposition calibration: agent learns MY startable granularity from what actually got done.
- [ ] Priority inference good enough that the brief's ONE task is reliably right; memory files mature.
- [ ] Time-blocking experiment (one week, kill-or-keep, §7).
- [ ] Loosen propose-first dials where trust is earned; revisit AGENTS.md.

### v2 / someday
- [ ] Flashcards (§7) when actively learning something.
- [ ] Voice capture via Telegram voice notes → transcription → journal.
- [ ] Email → task suggestions ("this email looks like it needs an action — track it?").

## 11. Source of truth & working process

- **This file is canonical once committed** to nixos-config (e.g. `docs/personal-agent/SPEC.md`). Any copies living in chat artifacts are historical after that point.
- **`CLAUDE.md` in the repo points here:** "the personal agent hub is specced in docs/personal-agent/SPEC.md; consult before touching `hosts/io` or `modules/nixos/agent/`." Every Claude Code session in the repo then starts with full design context.
- **Division of labor:** design/architecture thinking happens in the claude.ai Project (which holds the memory of *why* decisions were made); implementation happens in Claude Code sessions in the repo. The two do not share context automatically — this file and CLAUDE.md are the bridge.
- **When implementation invalidates a decision:** update this spec (decision log entry with the new rationale) in the same PR/commit as the change. The spec must never describe a system that no longer exists.

## 12. Decision log

| # | Decision | Rationale (short) |
|---|---|---|
| 1 | Hub = NixOS VPS, one flake | Declarative machinery is a core value; always-on required for timers/bot. |
| 2 | Hermes harness, Claude model, provider-agnostic | Assistant-shaped (messaging, memory, cron) vs conscripting a coding agent; model is config; skills portable via the agentskills.io standard (compatible with Claude Code etc., investment not stranded). Known risk: generic harness may underperform Claude Code's Claude-tuned loop — Claude Code headless is the fallback. |
| 3 | Content via Syncthing; history via server-side git; config via its own git repo (GitSync on Android). **Content and config superseded by 22** | Zero mobile jank for content + reviewable agent diffs + pinned reproducible config. |
| 4 | Laptop: all-Windows — Obsidian on Windows, vault on NTFS, native Windows Syncthing. **Syncthing superseded by 22** | Watcher and files must share an OS (9P notifications unreliable); deletes the WSL keep-alive problem; sync independent of WSL. WSLg Obsidian is the documented fallback. |
| 5 | Tasks = markdown (Obsidian Tasks) in vault | Minimalism; native phone UX = degradation story; greppable by agent. |
| 6 | Fastmail read-only token + label allowlist in MCP layer; no sending | Per-label tokens don't exist; bound the injection blast radius. |
| 7 | Credential-isolating MCP services (own user/env, socket to agent) | Agent can use, never read, secrets — self-hosted edge-injection analogue. |
| 8 | Journal: my words immutable-by-default; tags/links autonomous; synthesis marked; rewording propose-first | Trust ramp + journal stays trustworthy as what I wrote. |
| 9 | Telegram→journal: end-of-day distillation + explicit `/log` | Journal ≠ chat log; clutter is the worse failure mode. |
| 10 | Brief = calendar + ONE action | Overwhelm is the enemy; breadth on demand only. |
| 11 | Weekly planning agent-initiated, skippable | Rituals must cost nothing to miss. |
| 12 | Notion: full migration via official importer, agent cleans up | Wanted content preserved; doubles as propose-first shakedown. |
| 13 | exe.dev: not the hub; satellite trial in Phase 2 | Stateful pet vs disposable-VM sweet spot; one-flake property preserved; edge injection + publishing UX still worth scoping. |
| 14 | Flashcards deferred to v2 | No active learning target yet. |
| 15 | Hub built inside `weiijiie/nixos-config`: host via `mkHost`, services as `modules/nixos/agent/*`, MCP wrapper in `pkgs/`, shared vault-sync topology module | ~15-line host add; inherits overlays/home config; sync topology single-sourced; repo already converging on agent infra (llm-agents overlay, skills/, CLAUDE.md). Vault content, `.obsidian` repo, runtime state stay out. |
| 16 | Spec committed to repo = canonical; CLAUDE.md pointer; design in claude.ai Project, implementation in Claude Code | The two products don't share context; repo files are the bridge; spec must track reality (updated in the same commit as invalidating changes). |
| 17 | Hub is `io`; conventional US VPS, provider chosen at provision time; install via `disko` + `nixos-anywhere`, updates via `nixos-rebuild --target-host` | Provider migration becomes a rerun rather than a rebuild by hand, which is what makes "conventional VPS now, re-examine exe.dev later" cheap. Only `disko` becomes a flake input; `nixos-anywhere` runs via `nix run`. deploy-rs/colmena deferred until one host becomes several. Config is provider-agnostic: the `qemu-guest` profile is 11 virtio initrd modules and nothing else, so only the disk device name is provider-specific. |
| 18 | Secrets deployed out of band, not committed in any encrypted form; no agenix/sops-nix | Deliberate break with principle 1, accepted for now. Cost, stated plainly: a from-scratch rebuild is `nixos-anywhere` plus a manual secret-restore step, so the hub is not reproducible from the flake alone. Bought with it: nothing about secret names or recipient keys is published from a public repo, and no mechanism gets designed before the credentials it holds exist. Phase 0 needs no secret material at all, so nothing is blocked; revisit in Phase 1 when the Anthropic key and Telegram token arrive, at which point exe.dev-style edge injection is also back on the table. |
| 17a | exe.dev trialled for the hub and rejected; hub goes to a conventional VPS. **Superseded by 17b** | The supply chain works end to end: the flake builds NixOS as a 99-layer OCI image, GHCR hosts it privately, and exe.dev pulls and boots it from our own image while honouring our OCI labels. What does not work is the boot contract. exe.dev supplies the kernel and seeds a disk from the image, so there is no initrd, and its own base image compensates with a hand-written wrapper that mounts cgroup2 before systemd and a long list of masked units. Their platform also enters a VM over SSH on port 4722, served by something their base image provides and not documented anywhere. Reaching a working hub means reproducing that undocumented environment for NixOS and then answering two further unknowns (Syncthing with no inbound TCP, and whether integrations cover our credentials). The security prize was real but does not survive the cost: see 18a for what it would actually have bought. |
| 17b | exe.dev rejection premise overturned; hub location reopened, pending vault-sync ingress | The blocker behind 17a was reverse-engineering an undocumented boot environment blind. It fell when the exe.dev repo turned out to carry a reference NixOS config (`nix/configuration.nix`): the platform runs an init shim before `/init` that owns network, hostname and SSH ingress, and the image must ship a writable `/etc`, a seeded `/etc/passwd` including the shim sshd's privilege-separation user, and a Nix store database. With `hosts/io/oci.nix` and `pkgs/io-image.nix` matching that contract, the hub boots to a clean `running` in about 15 seconds and takes day-2 updates via `nixos-rebuild --target-host`, the same day-2 story as decision 17. Syncthing ingress is confirmed: peers open TCP 22000 to the hub over Tailscale directly. Still unanswered: whether integrations cover the credential set (18a). Choosing between exe.dev and a conventional VPS is now a judgement call, not a technical one. |
| 18a | Edge secret injection reframed: a security win, not a reproducibility win | exe.dev's proxy holds credentials so the VM never sees them, which is genuinely stronger than decision 18's out-of-band files. But creating an integration is itself an imperative, uncommitted step, so "recreate from scratch" stays a runbook either way. The gain is that a prompt-injected agent cannot exfiltrate a key it never had; the gain is not that the hub becomes reproducible from the flake. Worth revisiting only if exe.dev ships a supported non-Ubuntu path. |
| 19 | Vault access control keyed on a dedicated `vault` user and group | Syncthing, the snapshot timer and later Hermes all need the same directory. Naming the identity after the resource keeps "who may touch the vault" answerable by group membership rather than by which service happens to run as whom (SPEC §6 credential isolation). One trap: the upstream Hermes module chowns `services.hermes-agent.workingDirectory` to the agent's own user and group, so pointing it at the vault hands the directory to `hermes` and locks `vault` out of its own files. The hub therefore leaves `workingDirectory` at its default and names the vault through `settings.terminal.cwd` plus an added `ReadWritePaths`. Widening the agent's group instead is not an option: the module also copies the credential file to `$HERMES_HOME/.env` at mode 0640. |
| 20 | The hub is an appliance: home profile slimmed to coreutils, git, jq for every deployment of `io` | Supersedes §3's original "feels like my machine" intent. The full `home/common.nix` list is 8.4 GB of desktop tooling (nixvim, three toolchains, a container stack) the hub never runs; a separate devbox covers interactive dev if wanted. The slim profile is also what fits an image-based deploy under exe.dev's 10 GiB cap, so both variants now agree on shape. |
| 21 | Trial `obsidian-headless` (Obsidian Sync) as the vault transport, on a scratch vault. **Concluded by 22** | Simplicity pressure: option B deletes the two silently-mortal device daemons, the config-repo machinery and the tailnet from the sync path, and its bootstrap turned out fully scriptable (`ob login --email`, `sync-create-remote`, `sync-setup`; only account signup is web-only). Its maturity triggers are still unmet (v0.0.14, UNLICENSED, no nixpkgs), so this is a parallel trial against `/var/lib/ob-trial`, not a cutover; the live mesh is untouched. Package at `pkgs/obsidian-headless`, unit in `hosts/io/ob-trial.nix`, runbook and pass criteria in `docs/personal-agent/OB-TRIAL.md`. |
| 22 | Cut over to Obsidian Sync; Syncthing retired | The trial (`docs/personal-agent/OB-TRIAL.md`) met all six criteria: a 17-day soak on one process, and a login that survived a restart, a redeploy and a reboot. The cutover removes the two device daemons, the `.obsidian` config repo with GitSync, and Tailscale from the sync path, and the hub needs no inbound port for sync. Tailscale then had no job left on the hub and was removed from it. Accepted against it: decision 21's maturity triggers are still unmet (v0.0.14, UNLICENSED, not in nixpkgs), and the service refuses files by type and by size without any error. The hub turns the type filter off; the size ceiling is a plan limit (5 MB on Standard). Git on the hub supplies the audit trail the headless client cannot reach. The vault moved to `/var/lib/vault`, and the Syncthing data is archived on the hub at `/var/lib/syncthing-archive`. Re-evaluate if the client breaks on an upgrade or loses upstream support, Obsidian changes Sync's terms or pricing, or a refused file costs real work. |
| 23 | Agent jobs run on Hermes' scheduler, declared in the flake | Hermes' scheduler already delivers to Telegram, attaches skills, runs from the vault (loading its AGENTS.md) and tracks failures; systemd timers would rebuild all of that around a CLI. The scheduler keeps run state in `cron/jobs.json`, so Nix cannot own that file. Instead `hosts/io/hermes-cron.nix` declares the jobs and a deploy-time unit creates, edits and removes them by name through `hermes cron`. It removes only jobs it created itself, so jobs made from chat survive. Scheduled jobs get their own tool list (file, session search, the vault commit tool); left unset they would get Hermes' full default set, shell included. |
| 24 | The agent commits through one narrow tool, not a shell | Every agent write must be its own commit (principle 4), but Telegram deliberately has no shell (§6). A local MCP server (`pkgs/vault-mcp`) offers a single `commit(message, paths)` tool, run as `hermes`: it commits only the files named, refuses paths outside the vault or inside `.git`, and signs commits as Hermes so they stand apart from the snapshot timer's. Naming the server in each platform's tool list also makes those lists allowlists for MCP servers, so later servers do not join Telegram by default. |
| 25 | Agent memory stays in Hermes' home, approval-gated, with a one-way copy in the vault | Hermes keeps its memory (`MEMORY.md`, `USER.md`) in `$HERMES_HOME/memories` and rewrites the files at mode 0600, so they cannot live in the vault, where the sync client and the snapshot timer read as `vault`. Hermes' `memory.write_approval` stages every save, including background ones, until approved over Telegram (`/memory pending`); that is §6's review. A path unit copies the files into `agent/memory/` on each change and commits them, so memory is readable on every device and versioned; edits to the copy are overwritten. Larger notes the agent keeps (people, projects, patterns) are ordinary vault notes beside the copy. |
| 26 | The contract is `AGENTS.md`, rules only, changed only with approval | Hermes auto-loads `AGENTS.md` (plural) from the working directory, never `AGENT.md`, and loads it into every prompt, so it carries only the vault contract. Procedures live in flake-declared skills, which load on use and which the agent cannot rewrite. The contract is itself an instruction store the agent always obeys, so its edits need my approval, like rewording my prose. |
| 27 | A task is a checkbox tagged `#task` | The vault already held a 37-item packing template and 1,100 unchecked Notion checkboxes. Path exclusions depend on where things are filed; a marker does not. One extra word per task is the cost. `tasks.md` holds the tasks the agent creates and doubles as the dashboard. |
| 28 | Proposals are notes, not branches | A proposal is reviewed in Obsidian, where branches are invisible, and the commit tool commits only to `main`. A note in `agent/proposals/` holding the passage, the rewrite and the reason is the whole mechanism; the agent applies and commits it after I approve. |
| 29 | Hooks make every agent edit a commit and enforce the read-only paths | Committing is a separate step the agent can forget, and an uncommitted edit would be swept into a snapshot as mine. Shell hooks declared in the flake close that: one records each file the agent writes, one commits any still uncommitted at the end of the reply, marked as such. A fail-closed pre-write hook blocks writes to `Notion/`, `notion-attachments/`, `.git/`, `.obsidian/`, the memory copies and `agent/changes/`, and sends writes to `AGENTS.md` for my approval. Every agent commit adds a line to `agent/changes/YYYY-MM.md`, so the history is readable in Obsidian and by the agent. |
