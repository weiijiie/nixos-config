# Phase 0 runbook — substrate

Manual steps for the parts of SPEC §10 Phase 0 that cannot live in the flake.
Everything else is already declared: see `hosts/io/`, `modules/nixos/vault-sync.nix`
and `modules/nixos/vault-git.nix`.

What the flake already handles, so don't set it up by hand:

- disk layout and bootloader (`hosts/io/disko.nix`)
- Syncthing on the hub, its folder, and its ignore patterns
- the `vault` user and group, and `/var/lib/vault`
- the vault git repo and the 15-minute snapshot timer
- firewall openings for Syncthing (22000 TCP/UDP, 21027 UDP) and SSH

Anything added through the Syncthing web UI on the hub is reverted on restart:
`overrideDevices` and `overrideFolders` are on, so the flake wins.

## 1. Provision the VPS

2 vCPU / 4 GB / 40 GB, any stock Linux image the provider offers (Debian or
Ubuntu is fine; it gets overwritten). Add your SSH key so root login works.

**Verify:** `ssh root@<IP> "lsblk"` connects and lists a disk. If the disk is
`/dev/vda` rather than `/dev/sda`, change `disk` in `hosts/io/disko.nix` before
the next step.

## 2. Register the domain and point it at the hub

- `A` record: `io.<domain>` → the VPS IP
- `A` record: `*.<domain>` → the same IP (unused until the publishing story in
  SPEC §8, but the propagation wait is worth getting out of the way)

**Verify:** `dig +short io.<domain>` returns the VPS IP.

## 3. Install NixOS

From this repo on tinker:

```
nix run github:nix-community/nixos-anywhere -- --flake .#io root@<IP>
```

This kexecs into a RAM installer, partitions per `disko.nix`, and installs. The
box reboots into NixOS with the same IP.

**Verify:** `ssh root@<IP> "nixos-version && systemctl is-system-running"`.
`degraded` is worth investigating with `systemctl --failed`; `running` is clean.

## 4. Read the hub's Syncthing device ID

```
ssh root@<IP> "syncthing device-id --config=/var/lib/syncthing/.config/syncthing"
```

Put it in `modules/nixos/vault-sync.nix` as `devices.io.id`. It is not secret;
it is a public key fingerprint.

**Verify:** the value is a 63-character string of seven-character groups.

## 5. Windows Syncthing on the laptop

Obsidian, the vault and Syncthing all live on Windows; WSL is not involved
(SPEC §4, decision 4).

1. Install Syncthing for Windows from syncthing.net. Either use SyncTrayzor, or
   run `syncthing.exe` from a Task Scheduler task triggered "at log on" — the
   requirement is only that it starts without you remembering to start it.
2. Create the vault folder on NTFS, e.g. `C:\Users\<you>\Vault`.
3. In the web UI (`http://127.0.0.1:8384`): **Actions → Show ID**, and put that
   ID in `modules/nixos/vault-sync.nix` as `devices.tinker.id`.
4. Add the hub as a remote device using its ID from step 4.
5. Add the folder with **Folder ID exactly `obsidian-vault`** (the label is
   cosmetic; the ID is what pairs), path `C:\Users\<you>\Vault`, shared with the
   hub.
6. Under **Ignore Patterns** for that folder, enter the same list the hub uses:

   ```
   /.obsidian
   /.git
   /.stversions
   /.trash
   ```

7. Point Windows Obsidian at `C:\Users\<you>\Vault` as a vault.

**Verify:** with the hub deployed and IDs filled in on both sides, the folder
shows "Up to Date" on both. Then run `wsl --shutdown` and confirm a file created
on Windows still reaches the hub — sync must not depend on WSL.

## 6. Android

The official Syncthing Android app is discontinued. Use **Syncthing-Fork**
(package `com.github.catfriend1.syncthingfork`) from F-Droid, now maintained by
researchxxl.

1. Install it and grant storage permission.
2. Disable battery optimization for it, or Android will kill it in the
   background and sync will silently stop.
3. Add the hub as a device by ID; take the phone's own ID from the app and put
   it in `modules/nixos/vault-sync.nix` as `devices.phone.id`.
4. Add the folder with ID `obsidian-vault`, pointing at a shared-storage path
   Obsidian can also open, e.g. `/storage/emulated/0/Vault`. A path under the
   app's private directory will sync but Obsidian won't be able to open it.
5. Set the same ignore patterns as step 5.6.
6. Open the folder as a vault in Obsidian for Android.

**Verify:** the folder reaches "Up to Date" in the app.

## 7. Redeploy with the device IDs filled in

```
nixos-rebuild switch --flake .#io --target-host root@<IP>
```

The build happens on tinker and only the closure is copied.

**Verify:** the build prints no `services.vaultSync: no device ID` warning. On
the hub, `ssh root@<IP> "systemctl status syncthing"` is active, and the peers
show as connected.

## 8. Acceptance test (SPEC §10)

With WSL shut down (`wsl --shutdown`):

1. On the phone, add a line to any file in the vault.
2. It appears on the Windows laptop in Obsidian.
3. It appears on the hub: `ssh root@<IP> "ls -la /var/lib/vault"`.
4. Force a snapshot instead of waiting up to 15 minutes:

   ```
   ssh root@<IP> "systemctl start vault-snapshot && \
     sudo -u vault git -C /var/lib/vault log --oneline"
   ```

   A `human edits @ <timestamp>` commit exists.

## Day-2 commands

| Task | Command |
|---|---|
| Deploy a config change | `nixos-rebuild switch --flake .#io --target-host root@<IP>` |
| Syncthing web UI on the hub | `ssh -L 8384:127.0.0.1:8384 root@<IP>`, then `http://127.0.0.1:8384` |
| Vault history | `ssh root@<IP> "sudo -u vault git -C /var/lib/vault log --stat"` |
| Snapshot now | `ssh root@<IP> "systemctl start vault-snapshot"` |
| Rebuild the box from scratch | repeat steps 1 and 3; the vault restores from any Syncthing peer |
