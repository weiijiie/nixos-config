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

## What the trial must show

- [x] Hidden files stay local. Probes planted 2026-08-31: `.git/` and
      `.gitignore` never left the hub while a sibling `canary.md` reached the
      laptop. (Still community-reported behavior, not documented contract;
      re-verify after any `ob` upgrade.)
- [ ] The token survives a hub reboot and a redeploy without re-login.
      Service restart already re-authenticates from the stored token
      (2026-08-31); reboot and redeploy still to observe.
- [ ] Propagation latency phone → hub in continuous mode, measured, vs the
      ~30 s the beta docs imply.
- [x] Merge behavior, tested 2026-08-31 with deliberate same-position
      concurrent inserts: no conflict copy, no data loss, both devices
      converged — but the inserts interleaved mid-sentence
      (character-position merge, no semantic awareness). Verdict: strictly
      better than a conflict sidecar, yet the agent must still write to its
      own file regions (§4.1); same-position collisions jumble prose.
- [ ] Two weeks of `ob-sync-trial` uptime without a breaking vendor change (soak started 2026-08-31; call it 2026-09-14).

## Outcome

Record the result as a decision-log entry amending decision 21: cut over
(SPEC §4 rewrite, Syncthing layer deleted) or stay, with the trigger list
for re-evaluation.
