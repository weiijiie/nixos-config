# Phase 0 runbook — substrate

The manual steps behind SPEC §10 Phase 0, and the procedure for rebuilding.
The hub runs on exe.dev, and the hub, laptop and phone sync the vault through
Obsidian Sync (decision 22).

Everything else is declared: see `hosts/io/`, `modules/nixos/vault-sync.nix`
and `modules/nixos/vault-git.nix`.

What the flake handles, so don't set it up by hand:

- disk layout and bootloader on a conventional VPS (`hosts/io/disko.nix`),
  or the whole boot contract on exe.dev (`hosts/io/oci.nix`)
- the `vault-sync` service and its sync settings: file types, conflict
  strategy, and no editor settings on the hub
- the `vault` user and group, `/var/lib/vault` and `/var/lib/obsidian-sync`
- the vault git repo and the 15-minute snapshot timer

A setting changed by hand with `ob sync-config` is overwritten at the next
start of `vault-sync`.

## Provisioning

Two supported routes. The hub was built with the first; the second stays
current in case the location decision changes (SPEC decisions 17, 17b).

### As built — exe.dev

The platform boots a VM from an OCI image, so the image is install media in
the same sense `nixos-anywhere` is: it seeds the disk once, and every update
afterwards is `nixos-rebuild --target-host`.

```
nix build .#io-image
./result > io.tar
skopeo --insecure-policy copy --authfile <authfile> \
  docker-archive:io.tar docker://ghcr.io/<user>/io:<tag>
ssh exe.dev new --name=io-hub --image=ghcr.io/<user>/io:<tag> \
  --registry-auth=<user>:<token>
```

`io-image` is a *script* that writes the tarball on stdout, never materializing
a filesystem tree; `docker-archive:` needs a seekable file, so it goes via disk
rather than a pipe. GHCR needs a classic PAT (`write:packages` to push,
`read:packages` for exe.dev to pull); package visibility is independent of the
repository's. Extracted contents must stay under exe.dev's 10 GiB ceiling,
which is why the hub runs the slim appliance profile (decision 20).

**Verify:** `ssh io-hub.exe.xyz "systemctl is-system-running"` reports
`running` within a minute or so of creation.

### Alternative — conventional VPS

2 vCPU / 4 GB / 40 GB, any stock Linux image; it gets overwritten. Add your
SSH key so root login works. If the disk is `/dev/vda` rather than `/dev/sda`,
change `disk` in `hosts/io/disko.nix` first.

```
nix run github:nix-community/nixos-anywhere -- --flake .#io root@<IP>
```

This kexecs into a RAM installer, partitions per `disko.nix`, and installs.

**Verify:** `ssh root@<IP> "nixos-version && systemctl is-system-running"`.

### Domain and DNS — still outstanding

Not yet done, and nothing depends on it: exe.dev supplies
`io-hub.exe.xyz` with TLS, and sync needs no inbound path. Wanted for the
publishing surface in SPEC §8.

## 1. Link the hub to Obsidian Sync

The account, the Sync subscription and the remote vault (`Observer`,
end-to-end encrypted) already exist; account signup is web-only. Run these on
the hub as the vault user. Passwords are prompted; don't pass them as flags,
where they would land in shell history.

```
sudo -u vault env HOME=/var/lib/obsidian-sync ob login --email <email>
sudo -u vault env HOME=/var/lib/obsidian-sync ob sync-setup \
  --vault Observer --path /var/lib/vault --device-name io
```

The login token and the vault key now live under `/var/lib/obsidian-sync`,
readable only by `vault` (decision 18). Then arm and start the service:

```
sudo -u vault touch /var/lib/obsidian-sync/armed
sudo systemctl start vault-sync
```

Arm only after `sync-setup` has succeeded; until then the service stays
inactive.

**Verify:** `journalctl -u vault-sync` ends in `Fully synced`, and
`/var/lib/vault` holds the notes.

## 2. Laptop and phone

On each device, log the Obsidian app into the same account and connect to
`Observer` from **Settings → Sync**. On the laptop, keep the vault on NTFS
and outside any other sync engine's tree, not under OneDrive (SPEC §4,
decision 4).

In the same Sync settings, turn on syncing of **all other file types**. The
hub syncs every type, but a file only reaches it if the device that has it
uploads it.

## 3. Acceptance test

1. On the phone, add a line to any note.
2. It appears in Obsidian on the laptop.
3. It appears on the hub under `/var/lib/vault`.
4. A snapshot captures it — force one rather than waiting up to 15 minutes:

   ```
   ssh io-hub.exe.xyz "sudo systemctl start vault-snapshot && \
     sudo -u vault git -C /var/lib/vault log --oneline"
   ```

   A `human edits @ <timestamp>` commit exists.

## Day-2 commands

| Task | Command |
|---|---|
| Deploy a config change | `nixos-rebuild switch --flake .#io-oci --target-host wj@io-hub.exe.xyz --use-remote-sudo` |
| Sync status | `ssh io-hub.exe.xyz "journalctl -u vault-sync -n 20"` |
| Vault history | `ssh io-hub.exe.xyz "sudo -u vault git -C /var/lib/vault log --stat"` |
| Snapshot now | `ssh io-hub.exe.xyz "sudo systemctl start vault-snapshot"` |

## Rebuilding the hub from scratch

Repeat the provisioning route, redeploy, then step 1. The vault needs no
backup restore: `sync-setup` pulls it back from Obsidian's servers, which is
the property that makes the hub disposable. Two things do not come back that
way:

- The vault's git history exists only on the hub, so a rebuild starts it
  fresh.
- Secrets are deployed out of band (decision 18) and have to be put back by
  hand.
