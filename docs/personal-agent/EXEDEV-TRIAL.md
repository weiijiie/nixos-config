# exe.dev trial

Pulled forward from SPEC §10 Phase 2. The question is narrow: **can the hub run
on exe.dev without giving up the flake, and does that buy edge secret injection?**

Budget: one month of the Personal plan ($20). Do not pair the phone or laptop
against an exe.dev hub until the decision is made — that's the expensive manual
work and it should only be done once.

Their docs are readable without a browser: `ssh exe.dev doc` lists slugs,
`ssh exe.dev doc <slug>` prints one. That is the authoritative source; the
website renders client-side and is useless to fetch.

## Verdict: rejected for the hub

The supply chain works end to end. The flake builds NixOS as a ~100-layer OCI
image in about two minutes, GHCR hosts it privately, exe.dev pulls it with
`--registry-auth`, honours our OCI labels (it targeted the port from
`ExposedPorts`), and creates a VM that reports `running`.

The boot contract does not. systemd never starts, so nothing serves the HTTP
diagnostic and nothing answers exe.dev's own SSH port. Two fixes were tried and
neither was sufficient:

1. Dropping `virtualisation/docker-image.nix`. It marks the system
   containerized, and systemd then leaves `/sys` and `/sys/fs/cgroup` to a
   container runtime that does not exist here. Removing it was necessary
   (NixOS stage-2 mounts neither) but did not produce a boot.
2. Slimming the image below their 10 GiB extracted ceiling, 9.2 GB to 3.27 GB.
   Required to create the VM at all; unrelated to the boot failure.

**What actually blocks it is the absence of any diagnostic channel.** exe.dev
offers no console and no log access, and the VM is unreachable precisely
because the thing that would serve SSH or HTTP is the thing that failed. Each
further attempt is a blind ~20 minute cycle against the list of units exeuntu's
Dockerfile masks by hand, which is that same work already done for Ubuntu.

Their platform supplies the kernel and seeds a disk from the image, so there is
no initrd and no stage-1. exeuntu compensates with a wrapper that mounts cgroup2
before systemd and roughly forty masked units. Reaching a booting NixOS means
reproducing that, undocumented, without observability, and only then reaching
the two unknowns that were supposed to decide the trial: Syncthing with no
inbound TCP, and whether integrations cover our credentials.

Still worth doing, asynchronously and off the critical path: ask them what a
non-exeuntu image must provide at init. It is a short question and they are
responsive. If the answer is small, this reopens cheaply.

Two findings outlive the trial and are not about exe.dev:

- Importing `virtualisation/docker-image.nix` for an image-based deploy is
  wrong on any platform that boots real VMs from images rather than running
  containers.
- The hub carried 8.4 GB of desktop tooling from `home/common.nix` — an editor
  at 4.5 GB, three toolchains, a container stack — none of which it runs.
  Invisible on a VPS, fatal against an image ceiling.

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

## Decision rule, revised

| Result | Verdict |
|---|---|
| NixOS image boots, and Syncthing reaches peers via Tailscale | **Move the hub.** Same flake, secrets off the box, HTTPS for free. |
| Boots, but Syncthing can only sync via public relays | **Judgement call.** Weigh a third party in the sync path against the secret-injection win. |
| NixOS image won't boot on their kernel | **Stop, don't debug it.** Hetzner, and revisit if they ever ship custom kernels. |

## Next: boot the image (step 3)

The image builds. `nix run github:nix-community/nixos-generators -- --flake .#io -f docker`
produces **a rootfs tarball, not a Docker archive** — no `manifest.json`, just
`init`, `systemd` and 367k `nix/store` entries, 1.69 GB compressed. So it needs
`docker import` with the entrypoint set to `/init`, not `docker load`.

Blocker on this machine: the Docker CLI is present but no daemon is running in
WSL. Either start Docker Desktop, or add a `dockerTools.buildImage` output to the
flake so the OCI image is built by nix and pushed with skopeo — the second is
more work but keeps the push reproducible and matches principle 1.

- [ ] Build/import the image and push it to ghcr.io
- [ ] `ssh exe.dev new --name io-hub --image ghcr.io/... --registry-auth=...`
- [ ] **Pass:** `systemctl is-system-running` responds, and `systemctl status
      syncthing` shows the unit up — that proves systemd came up as PID 1 under
      their kernel and ran our units.
- [ ] Then test Tailscale ingress before anything else, since that's the blocker.

Note the image is 1.69 GB largely because `home/common.nix` brings gcc, go,
kubectl, ngrok, delve and nvim — §3 asked for the hub to "feel like my machine."
That reads differently for an image you push. A leaner `homeModules` set for the
hub is worth revisiting either way.

## Whichever way it goes

This ends with a decision-log entry in `SPEC.md` §12 amending decisions 13 and
18, in the same commit as any config change. "Stay on Hetzner" is still a result
worth recording, so the question doesn't get reopened from scratch in three
months.
