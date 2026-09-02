# Obsidian Sync transport trial

Evaluates official `obsidian-headless` (SPEC §4 option B, decision 21) on a
scratch vault at `/var/lib/ob-trial/vault`, in parallel with the live
Syncthing mesh. Never point it at `/var/lib/vault`: two sync engines on one
directory conflict.

The hub runs `ob sync --continuous` via the `ob-sync-trial` unit
(`hosts/io/ob-trial.nix`), dormant until armed below. `ob` is on the hub's
PATH.

## Bootstrap (manual, once)

1. Create an Obsidian account and buy a Sync subscription at obsidian.md.
   Account creation is web-only; everything after is CLI.
2. On the hub, as the service identity (passwords are prompted; don't pass
   them as flags, they'd land in shell history):

   ```sh
   sudo -u vault env HOME=/var/lib/ob-trial ob login --email <email>
   sudo -u vault env HOME=/var/lib/ob-trial ob sync-create-remote \
     --name Observer --encryption end-to-end
   sudo -u vault env HOME=/var/lib/ob-trial ob sync-setup \
     --vault Observer --path /var/lib/ob-trial/vault --device-name io
   sudo -u vault env HOME=/var/lib/ob-trial ob sync-config \
     --path /var/lib/ob-trial/vault --conflict-strategy merge
   ```

   The trial's remote vault is named `Observer`; it was created from the
   desktop UI, so the `sync-create-remote` step was skipped in practice.

   The auth token and vault key live under `/var/lib/ob-trial` (decision 18:
   out of band, owned by `vault`).
3. Arm and start:

   ```sh
   sudo touch /var/lib/ob-trial/armed
   sudo systemctl start ob-sync-trial
   ```
4. On the phone and laptop, log the Obsidian app into the same account and
   add the `ob-trial` remote vault from Sync settings.

## Credential model, noted up front

These credentials cannot use exe.dev edge injection (decision 18a): the auth
token travels in request bodies and WebSocket frames, not headers, against a
hardcoded base URL, and the end-to-end vault key must exist on the box by
design. Option B therefore keeps decision 18's on-box out-of-band model,
where Syncthing holds no credential at all. Weigh this in the outcome.

The client has no token-refresh mechanism: the signin token lives until
revoked (password change, sign-out-everywhere), and a subscription lapse
stops sync outright. Either failure leaves the unit retry-looping silently,
so a cutover must add the hub sync unit to the §9 staleness alerting.

## What syncs, as observed

Two independent channels, which is why no exclusion config is needed for the
git layer:

- **Vault files** — notes plus the attachment types in `--file-types`
  (image, audio, video, pdf by default). Dot-prefixed paths are excluded
  wholesale: `.git/` and `.gitignore` stayed on the hub, and the laptop's
  `.obsidian/*` never arrived. `--excluded-folders` exists for keeping
  *visible* folders local, which nothing currently needs.
- **Config categories** — `.obsidian` settings travel through a separate
  opt-in channel (`--configs`: app, appearance, appearance-data, hotkey,
  core-plugin, core-plugin-data, community-plugin, community-plugin-data),
  currently `none` on the hub.

That split suits the design: devices can share settings among themselves
while the hub, which runs no editor, keeps configs off and receives only
markdown and attachments. A cutover would therefore retire SPEC §4's
separate `.obsidian` git repo and the GitSync app along with it.

Category membership is fixed in the client, and two consequences follow for
§4's config plan. In its favour, `workspace.json` and `workspace-mobile.json`
are refused unconditionally, so the per-device UI state §4 planned to
gitignore cannot leak at all, and plugin `main.js` travels under
community-plugin-data, giving §4's pinned-identical-plugins property without
a repo. Against it, the toggles are all-or-nothing per category with no
per-file escape: plugin `data.json` is welded to `main.js` and
`manifest.json` in community-plugin-data, and `graph.json` falls in
core-plugin-data with every other top-level json. §4 expected to exclude
exactly those individually, which a git repo can express and this cannot.

## What the trial must show

- [x] Hidden files stay local. Probes planted 2026-08-31: `.git/` and
      `.gitignore` never left the hub while a sibling `canary.md` reached the
      laptop. (Still community-reported behavior, not documented contract;
      re-verify after any `ob` upgrade.)
- [ ] The token survives a hub reboot and a redeploy without re-login.
      Service restart already re-authenticates from the stored token
      (2026-08-31); reboot and redeploy still to observe.
- [x] Propagation latency. A 292 KB attachment reached the hub in under 20
      seconds, better than the ~30 s polling interval the docs imply. Phone to
      hub not separately measured.
- [x] Merge behavior, tested 2026-08-31 with deliberate same-position
      concurrent inserts: no conflict copy, no data loss, both devices
      converged — but the inserts interleaved mid-sentence
      (character-position merge, no semantic awareness). Verdict: strictly
      better than a conflict sidecar, yet the agent must still write to its
      own file regions (§4.1); same-position collisions jumble prose.
- [x] Behaviour under a real workload, tested 2026-09-01 with a 2,324-file
      Notion import (4,090 files, 386 MB): the markdown and ordinary
      attachments arrived, but files were **dropped silently** by two separate
      mechanisms, with the unit still `active` and nothing logged. After
      repairing extensions, 11 remain unsynced. See "Silent exclusions" below.
      Syncthing has neither mechanism.
- [ ] Two weeks of `ob-sync-trial` uptime without a breaking vendor change (soak started 2026-08-31; call it 2026-09-14).

## Silent exclusions

A 201 MB Notion import left the hub 34 MB short, with no error anywhere; the
gap was only visible by diffing file lists. Two causes, neither of which
announces itself:

- **File type.** 17 `.bin` files (5.6 MB) never left the laptop. Notion writes
  web-clipped images without a usable extension, and `.bin` is not image,
  audio, video or pdf, so it falls under `unsupported`, which is off by
  default. Renaming to the real extension fixes both sync and Obsidian's
  rendering and is the better triage, but only rescues files whose true type
  is one of the four supported categories: all 16 `.bin` images crossed within
  seconds of being renamed, while the one that was really an XHTML article did
  not, because HTML is unsupported too. Office documents (`.doc`, `.docx`),
  `.json` and anything else outside those four categories are excluded the
  same way, which is not an edge case for a vault holding real material.
- **File size.** Files over the Standard plan's 5 MB ceiling are refused.
  Measured, not assumed: the largest file that synced is 4.11 MB and the
  smallest that did not is 6.2 MB. This is a plan limit, not a setting; Plus
  raises it to 200 MB. Across the finished 4,090-file import, seven files were
  held back this way, including an 11 MB reference PDF.

The exclusions themselves are defensible. The silence is the finding: notes
reached the hub referencing images that never did, so the agent would read a
vault with broken references and no signal that anything was missing. Weigh
this against Syncthing, which has no type filter and no size ceiling and moved
the same content whole.

## The audit trail, supplied on the hub

Obsidian Sync keeps per-file version history, but only the app can reach it:
the protocol has `history`, `restore` and `deleted` operations and the CLI
exposes none of them, so a headless hub gets nothing. It is also per-file
rather than per-change, carries no messages, and lives with the account.

That gap is closed by pointing `services.vaultGit` at the trial vault, which
the module already supports since its `path` is a free option. Git and the
transport were always orthogonal (SPEC §4's two layers); nothing about the
history layer depended on Syncthing. Two properties make the pairing clean:

- Dot-directories are never uploaded, so `.git` and the generated
  `.gitignore` stay hub-local with no exclusion config at all. Under
  Syncthing both needed explicit `.stignore` entries.
- Attachments are committed rather than ignored. That is deliberate: this
  transport has demonstrated silent exclusions, so a complete local copy with
  history is worth more here than it would be under Syncthing. The initial
  commit is 4,072 files and a 328 MB repo.

What git cannot recover is anything that never arrived: the 11 files held
back by type or size are absent from the hub and therefore from its history.

## Outcome

Record the result as a decision-log entry amending decision 21: cut over
(SPEC §4 rewrite, Syncthing layer deleted) or stay, with the trigger list
for re-evaluation.
