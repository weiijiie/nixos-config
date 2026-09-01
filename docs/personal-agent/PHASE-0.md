# Phase 0 runbook — substrate

The manual steps behind SPEC §10 Phase 0, as actually carried out, and the
procedure for rebuilding. Phase 0 is complete: the hub runs on exe.dev, all
three Syncthing peers are paired, and the acceptance test passed.

Everything else is declared: see `hosts/io/`, `modules/nixos/vault-sync.nix`
and `modules/nixos/vault-git.nix`.

What the flake handles, so don't set it up by hand:

- disk layout and bootloader on a conventional VPS (`hosts/io/disko.nix`),
  or the whole boot contract on exe.dev (`hosts/io/oci.nix`)
- Syncthing on the hub, its folder, and its ignore patterns
- the `vault` user and group, and `/var/lib/vault`
- the vault git repo and the 15-minute snapshot timer
- Tailscale, and the firewall openings each platform needs

Anything added through the Syncthing web UI on the hub is reverted on restart:
`overrideDevices` and `overrideFolders` are on, so the flake wins.

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
`io-hub.exe.xyz` with TLS, and Tailscale carries sync. Wanted for the
publishing surface in SPEC §8.

## 1. Read the hub's Syncthing device ID

Syncthing runs as the `vault` user, so ask for the ID as that user:

```
ssh io-hub.exe.xyz \
  "sudo -u vault env HOME=/var/lib/syncthing syncthing device-id"
```

Put it in `modules/nixos/vault-sync.nix` as `devices.io.id`. It is not secret;
it is a public key fingerprint.

**Verify:** a 63-character string of seven-character groups.

## 2. Windows Syncthing on the laptop

Obsidian, the vault and Syncthing all live on Windows; WSL is not involved
(SPEC §4, decision 4).

1. Install Syncthing as a **Windows service** (Bill-Stewart's Syncthing
   Windows Setup), so it starts before login and cannot be closed by accident.
   SyncTrayzor works too but only runs while you are logged in.
2. Put the vault on NTFS and **outside any other sync engine's tree** — not
   under OneDrive. The live vault is at
   `C:\Users\<you>\Obsidian\Vault of Souls`.
3. In the web UI (`http://127.0.0.1:8384`): **Actions → Show ID**, and put
   that ID in `modules/nixos/vault-sync.nix` as `devices.tinker.id`.
4. Add the hub as a remote device using its ID from step 1, and set its
   **address** to the hub's tailnet address, `tcp://100.70.123.10:22000`.
   Leaving it `dynamic` relies on discovery, which cannot find a machine with
   no public IP.
5. Accept the folder offer the hub then sends. Set the path **in that dialog**
   — a Syncthing folder's path cannot be changed afterwards — and point it at
   the vault root itself, not a directory containing the vault.
6. Under **Ignore Patterns** for that folder, enter the same list the hub uses:

   ```
   /.obsidian
   /.git
   /.gitignore
   /.stversions
   /.trash
   ```

7. Point Windows Obsidian at that folder as a vault.

**Verify:** the folder shows "Up to Date" on both sides. Then run
`wsl --shutdown` and confirm a file created on Windows still reaches the hub.

## 3. Android

The official Syncthing Android app is discontinued. Use **Syncthing-Fork**
(`com.github.catfriend1.syncthingfork`) from F-Droid.

1. Install it and grant storage permission.
2. Disable battery optimization for it, or Android kills it in the background
   and sync silently stops. Check its run conditions too: a wifi-only default
   means no sync on mobile data.
3. Add the hub as a device by ID with the same tailnet address as step 2.4,
   and put the phone's own ID in `vault-sync.nix` as `devices.phone.id`.
4. **Accept the hub's folder offer** rather than creating a folder by hand: a
   manually created folder gets a random folder ID and will never pair. Point
   it at shared storage Obsidian can open, e.g.
   `/storage/emulated/0/Documents/Vault`; a path under the app's private
   directory syncs but Obsidian cannot open it.
5. Set the same five ignore patterns.
6. Open the folder as a vault in Obsidian for Android.

## 4. Redeploy with the device IDs filled in

```
nixos-rebuild switch --flake .#io-oci --target-host wj@io-hub.exe.xyz \
  --use-remote-sudo
```

The build happens on tinker and only the closure is copied. Deploys run as
`wj`, whose locally-built paths are unsigned, which is why the hub puts
`@wheel` in `nix.settings.trusted-users`.

**Verify:** the build prints no `services.vaultSync: no device ID` warning,
and `systemctl status syncthing` on the hub shows the peers connected.

## 5. Acceptance test

With WSL shut down (`wsl --shutdown`):

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
| Syncthing web UI on the hub | `ssh -L 8384:127.0.0.1:8384 io-hub.exe.xyz`, then `http://127.0.0.1:8384` |
| Syncthing state without the UI | `ssh io-hub.exe.xyz` then query `localhost:8384/rest/...` with the API key from `/var/lib/syncthing/.config/syncthing/config.xml` |
| Vault history | `ssh io-hub.exe.xyz "sudo -u vault git -C /var/lib/vault log --stat"` |
| Snapshot now | `ssh io-hub.exe.xyz "sudo systemctl start vault-snapshot"` |

## Rebuilding the hub from scratch

Repeat the provisioning route, then redeploy. The vault itself needs no
backup restore — it comes back from any Syncthing peer once the hub is paired
again, which is the property that makes the hub disposable. Secrets are the
exception: they are deployed out of band (decision 18) and have to be put back
by hand.
