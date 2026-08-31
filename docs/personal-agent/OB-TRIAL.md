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
     --name ob-trial --encryption end-to-end
   sudo -u vault env HOME=/var/lib/ob-trial ob sync-setup \
     --vault ob-trial --path /var/lib/ob-trial/vault --device-name io
   sudo -u vault env HOME=/var/lib/ob-trial ob sync-config \
     --path /var/lib/ob-trial/vault --conflict-strategy merge
   ```

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

## What the trial must show

- [ ] Hidden files stay local: put a `.git` dir and a `.gitignore` in the
      trial vault on the hub; confirm neither reaches another device.
      (Community-reported behavior, not documented contract.)
- [ ] The token survives a hub reboot and a redeploy without re-login.
- [ ] Propagation latency phone → hub in continuous mode, measured, vs the
      ~30 s the beta docs imply.
- [ ] Merge behavior: edit the same note on two devices within the sync
      window; confirm a real merge, not a conflict copy or silent loss.
- [ ] Two weeks of `ob-sync-trial` uptime without a breaking vendor change.

## Outcome

Record the result as a decision-log entry amending decision 21: cut over
(SPEC §4 rewrite, Syncthing layer deleted) or stay, with the trigger list
for re-evaluation.
