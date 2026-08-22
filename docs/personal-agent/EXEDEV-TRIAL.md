# exe.dev trial

Pulled forward from SPEC §10 Phase 2. The question is narrow: **can the hub run
on exe.dev without giving up the flake, and does that buy edge secret injection?**

Budget: one month of the Personal plan ($20). Do not pair the phone or laptop
against an exe.dev hub until the decision is made — that's the expensive manual
work and it should only be done once.

Their docs are readable without a browser: `ssh exe.dev doc` lists slugs,
`ssh exe.dev doc <slug>` prints one. That is the authoritative source; the
website renders client-side and is useless to fetch.

## Verdict: boot solved; hub location is an open decision

The rejection premise fell. The exe.dev repo carries a reference NixOS config
(`nix/configuration.nix` and `nix/Dockerfile`), and it documents the boot
contract that earlier attempts were guessing at. With `hosts/io/oci.nix` and
`pkgs/io-image.nix` matching that contract, the hub boots to a clean
`systemctl is-system-running` = `running` in about 15 seconds, with zero
failed units: syncthing, the vault snapshot timer and home-manager all come
up. Day-2 updates work with `nixos-rebuild switch --target-host`, the same
story as the conventional-VPS plan; the image is install media only.

The contract, as their reference config states it:

- The platform runs a shim (`/exe.dev/bin/exe-init`) before `/init`. It
  configures the NIC, routes, DNS, hostname and hosts file, and serves SSH
  with an embedded daemon. NixOS must not run DHCP, resolvconf, a hosts file
  or its own sshd against it.
- The system is container-marked (`profiles/docker-container.nix`,
  `container=oci` in the image env); exe-init plays the container runtime.
- `/etc` must be a real writable directory in the image, not the store
  symlink `toplevel` ships, because exe-init writes into it before activation.
- `/etc/passwd` must be seeded with the login user and an `sshd`
  privilege-separation account, and NixOS activation must keep that account,
  or exe-init's sshd dies when activation rewrites `/etc/passwd`.
- The image must carry a Nix store database (`includeNixDB`); without it
  every nix invocation on the box, home-manager activation included, rejects
  the store paths as invalid.
- Login shells go through a `/bin/exe-shell` wrapper because their sshd
  supplies a conventional PATH.

What earlier attempts got wrong, for the record: dropping the container
marking was backwards, the store-symlinked `/etc` blocked exe-init in every
attempt, our sshd and DHCP raced theirs, and disko's `fileSystems` pointed
systemd at partitions that do not exist there.

Vault-sync ingress is answered: the hub joined the tailnet and a peer opens
TCP 22000 to it over Tailscale directly, no relays. Tailscale is thereby
load-bearing for sync on exe.dev, the cost named in the findings below.

Still untested, the last open question: whether integrations cover the
credential set (Anthropic, Fastmail, Telegram); the Telegram base-path idea
needs a bot token to try.

Two findings outlive the trial and are not about exe.dev:

- An image-based deploy has to match the platform's init contract exactly;
  the same image that is correct for exe.dev (container-marked, writable
  /etc, seeded passwd) would be wrong on a platform that boots real VMs.
- The hub carried 8.4 GB of desktop tooling from `home/common.nix` that it
  never runs. Invisible on a VPS, fatal against an image ceiling.

## Findings in detail

Three of the four original unknowns are answered from the docs, without booting
anything. One new blocker appeared that outranks all of them.

### Answered: integrations take arbitrary hosts (was unknown #3)

Not catalog-only. The generic HTTP proxy integration takes any target URL and
injects any header:

```
integrations add http-proxy --name mirror --target https://httpbin.org/ \
  --header prettiest-of-them-all:me --attach vm:<vm>
```

The VM then calls `http://mirror.int.exe.xyz/...` and the header is added on the
way out. `--bearer` exists for bearer tokens, and the credential is stored
server-side, never visible from the VM. So:

- **Anthropic** (`x-api-key` header) — works. This is the secret most worth
  getting off the box.
- **Fastmail JMAP** (`Authorization: Bearer`) — works, via `--bearer`.
- **Telegram** — may work after all. The token is a path segment, but `--target`
  is a full URL, and the httpbin example shows the request path appended to the
  target. A target of `https://api.telegram.org/bot<TOKEN>/` would put the token
  server-side where the VM can't read it. Untested, worth ten minutes.

There is also a token-mint integration type that runs OAuth client-credential
dances server-side, which is the shape Google Calendar will need in Phase 2.

### Answered: private images work (was unknown #2)

Two routes: `--registry-auth=USER:TOKEN` against ghcr.io, Docker Hub, GitLab or
ECR; or run a registry on an exe.dev VM and pull from `<vm>.exe.xyz/image:tag`.

### Answered, and the model is better than assumed (was unknown #1)

From `doc faq/how-exedev-works`: a VM starts from a container image, and exe.dev
"hooks it up with a block device with the image on it." The image **seeds a
normal persistent disk at creation**. After that it is an ordinary filesystem —
their own editorial (`doc serverful`) is titled "Persistent disks, not
serverless."

This kills the immutable-rootfs concern entirely. It also changes the workflow:
**you never redeploy an image.** The image is install media, exactly like
`nixos-anywhere`, and day-2 updates are `nixos-rebuild switch --target-host`
against the box — identical to the Hetzner plan. There is no `set-image` command
in the CLI, which is consistent with that reading.

### New blocker: no arbitrary TCP ingress

The VM gets **no public IP**. exe.dev terminates TLS and proxies HTTP to your VM
(ports 3000–9999 reachable as `https://<vm>.exe.xyz:PORT/`), and handles SSH at
`ssh <vm>.exe.xyz`. That is the whole ingress story. VMs are also isolated from
each other with no private network.

Syncthing needs inbound TCP 22000, which is not HTTP. **Phone and laptop cannot
dial the hub directly.** Two ways out:

1. **Syncthing relays.** Syncthing falls back to public relays when a direct
   connection isn't possible. Throughput is irrelevant for markdown, but it puts
   third-party infrastructure in the sync path.
2. **Tailscale.** exe.dev's own cross-VM networking doc recommends it. The hub
   joins the tailnet, peers reach it over WireGuard, Syncthing connects normally.

Tailscale is listed in SPEC §10 as "optional but nice." On exe.dev it becomes
**load-bearing** for vault sync. That is a real cost against principle 3
(graceful degradation): another service in the critical path.

### New constraint: the kernel is theirs

"You don't get to choose which kernel you're using." NixOS normally owns the
bootloader and kernel, so on exe.dev that whole layer is bypassed:
`hosts/io/disko.nix` and the GRUB config are dead weight, and anything depending
on kernel modules they didn't build (zram for `zramSwap`, nftables for
`networking.firewall`) may not work. A `hosts/io/` variant would be needed with
the bootloader disabled. The firewall matters much less anyway with no public IP.

## Decision rule, remaining

| Result | Verdict |
|---|---|
| Syncthing reaches peers via Tailscale | **Confirmed.** Moving the hub is a live option: same flake, secrets off the box, HTTPS for free; weigh Tailscale being load-bearing. |
| Syncthing can only sync via public relays | **Judgement call.** A third party in the sync path against the secret-injection win. |

## Next: vault-sync ingress

- [x] Join the hub to the tailnet and confirm a laptop can open TCP 22000 to
      it over Tailscale. Passed: direct connection from tinker to the hub's
      tailnet address.
- [ ] Ten-minute test of the Telegram base-path integration
      (`--target https://api.telegram.org/bot<TOKEN>/`).

## Whichever way it goes

This ends with a decision-log entry in `SPEC.md` §12 amending decisions 13 and
18, in the same commit as any config change. "Stay on Hetzner" is still a result
worth recording, so the question doesn't get reopened from scratch in three
months.
