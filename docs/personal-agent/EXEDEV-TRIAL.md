# exe.dev trial

Pulled forward from SPEC §10 Phase 2. The question is narrow: **can the hub run
on exe.dev without giving up the flake, and does that buy edge secret injection?**

Budget: one month of the Personal plan ($20). Timebox: one sitting. Do not pair
the phone or laptop against an exe.dev hub until the decision is made — that's
the expensive manual work and it should only be done once.

## Decision rule, agreed before starting

Write the answers down as you go; decide at the end, not while you're in it.

| Result | Verdict |
|---|---|
| NixOS image boots, state persists, header injection works | **Move the hub.** Strictly better than Hetzner: same flake, plus secrets off the box. |
| Boots and persists, but integrations are catalog-only | **Stay on Hetzner.** The main prize was secret injection; HTTPS alone doesn't pay for the vendor risk. |
| State does not survive a redeploy and there's no volume option | **Stop.** A stateful hub on an immutable rootfs is a trap. |
| NixOS image won't boot | **Stop, don't debug it.** Running nix-on-Ubuntu instead is a different project than the one specced. |

## What the flake already answers, for free

`nixos-generators` builds a NixOS system as an OCI image with systemd as PID 1.
Two things to know before you start:

- It is **not** the `oci` format in nixpkgs — that one is Oracle Cloud
  Infrastructure and produces a qcow2 disk image. Wrong thing entirely.
- The `docker` format lives in `nixos-generators` only, and its own description
  hedges: "uses systemd to run, probably only works in podman."

That hedge is about shared-kernel containers, where systemd can't get at cgroups.
exe.dev runs real KVM VMs with their own kernel, so the usual objection doesn't
apply — but that's an argument, not evidence, which is what step 3 is for.

```
nix run github:nix-community/nixos-generators -- --flake .#io -f docker
```

## 1. Sign up and read three specific things

Personal plan, $20/mo. Their docs render client-side, so I could not read them;
these are the three answers to find before touching anything:

- [ ] What the CLI is, and how to create a VM from a **custom** image.
- [ ] Whether a custom image can come from a **private** registry, or only public
      Docker Hub. (If public-only, the hub's image is public — it contains no
      secrets by design, but check what it does leak: hostnames, your SSH public
      key, the vault path.)
- [ ] How disk persistence works across a VM being recreated or its image
      changed. This is the answer that matters most; step 4 verifies whatever
      the docs claim.

## 2. Sanity-check the platform first

- [ ] Boot their stock image (`exeuntu`, or `alpine:latest`) and SSH in.
- [ ] Confirm the HTTPS front door works: serve anything on a port, hit the URL.

**Pass:** you have a shell and a working URL inside ten minutes. If this part is
awkward, the rest will be worse.

## 3. Boot the NixOS image — unknown #2

- [ ] Build it: `nix run github:nix-community/nixos-generators -- --flake .#io -f docker`
- [ ] Load and push it to whatever registry they accept.
- [ ] Create a VM from it.

**Pass:** `systemctl is-system-running` returns `running` or `degraded`, and
`systemctl status syncthing` shows the service up. Syncthing starting is the real
signal — it proves systemd came up as PID 1 and ran our units, not just that the
image unpacked.

**If it fails:** capture the console output and stop. Don't debug the boot path;
that's the trap this timebox exists to avoid.

## 4. The persistence test — unknown #1, the one that decides it

This is the test worth doing carefully, because a stateful pet on an immutable
rootfs fails slowly and expensively rather than loudly.

- [ ] On the running VM: `echo canary > /var/lib/vault/canary.txt`
- [ ] Also note the Syncthing device ID:
      `syncthing device-id --config=/var/lib/syncthing/.config/syncthing`
- [ ] Make a trivial change to `hosts/io/default.nix` (a comment is enough),
      rebuild the image, push it, and redeploy the VM from the new image.
- [ ] Check: does `canary.txt` still exist? Is the device ID **the same**?

**Pass:** both survive. The device ID is the sharper test — if it changes, the
Syncthing identity is regenerated on every deploy and every peer has to re-pair.
That alone is disqualifying.

**Partial:** state is lost but they offer a separate persistent volume. Then the
design needs `/var/lib/vault` and `/var/lib/syncthing` on that volume, which is a
real but manageable change. Note it and keep going.

**Fail:** state is lost and there's no volume. Stop.

## 5. Integration test — unknown #3

The prize is that a prompt-injected agent can't exfiltrate a credential that was
never on the box. Test whether that covers *our* credentials, not their catalog's.

Three services, and they do **not** behave the same way:

- [ ] **Anthropic** — auth is the `x-api-key` header. This is the ideal case for
      a header-injecting proxy, and it's the most valuable secret to get off the
      box. Test this one first.
- [ ] **Fastmail JMAP** — auth is `Authorization: Bearer <token>`. Also a header,
      so it should work the same way. Confirm a generic HTTP proxy integration
      can target an arbitrary host, since Fastmail won't be in their catalog.
- [ ] **Telegram** — auth is a **path segment**: `api.telegram.org/bot<TOKEN>/method`.
      A proxy that injects headers structurally cannot help here unless it also
      rewrites paths. Expect this one to fail, and check whether they support it
      anyway.

**Pass:** Anthropic works. That's the big one.

If Telegram can't be injected, its token stays on the box. That's a bounded loss:
a leaked bot token lets someone read messages sent to the bot and post as it, but
the Hermes gateway allowlist is on your inbound user ID, so it doesn't hand over
the agent. Worth knowing, not worth failing the trial over.

## 6. Check the limits — unknown #4

- [ ] Note the transfer allowance: 200 GB/mo against Hetzner's 20 TB, overage at
      $0.05/GB. Fine for markdown sync and a chat bot; a real ceiling if the
      publishing story in §8 ever carries traffic.
- [ ] Disk: 25 GB default per VM out of a 100 GB pool. Check the nix store's
      appetite — a NixOS system with `home/common.nix` is not small, and
      `nix.gc` is already set to weekly with a 30-day window in `hosts/io`.

## 7. Decide and write it down

Whichever way it goes, this ends with a decision-log entry in
`docs/personal-agent/SPEC.md` §12 amending decisions 13 and 18, in the same
commit as any config change. If the answer is "stay on Hetzner," that's still a
result worth recording, so the question doesn't get reopened from scratch in
three months.
