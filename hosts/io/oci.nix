# Variant of the hub for exe.dev, which seeds a VM's disk from a container
# image and supplies the kernel itself.
#
# Deliberately not `virtualisation/docker-image.nix`: that marks the system as
# containerized, and systemd then leaves /sys and /sys/fs/cgroup to the
# container runtime. Nothing here is a container runtime, so those never get
# mounted and systemd dies before reaching any unit. Running unmarked lets
# systemd mount them itself, which is what exe.dev's own base image relies on.
#
# There is no initrd, so anything a stage-1 would normally do has to be absent
# or handled by systemd.
{
  lib,
  pkgs,
  ...
}:
{
  # The platform owns the boot path.
  boot.loader.grub.enable = lib.mkForce false;

  # No public IP and no inbound TCP, so the firewall guards nothing and would
  # need netfilter modules this kernel may not carry.
  networking.firewall.enable = lib.mkForce false;

  # Socket activation misbehaves without a full device tree.
  services.openssh.startWhenNeeded = lib.mkForce false;

  # exe.dev caps an image's extracted contents at 10 GiB, and home/common.nix
  # accounts for 8.4 GB of ours: an editor, three toolchains and a container
  # stack the hub never runs. Deploys come from tinker, so the hub needs enough
  # to read a file and inspect a unit.
  home-manager.users.wj.basePackages = lib.mkForce (
    with pkgs;
    [
      coreutils
      git
      jq
    ]
  );

  # A container has no channels, and NIX_PATH reaches /etc/pam/environment,
  # which would pull a whole nixpkgs checkout into the image.
  nix.nixPath = lib.mkForce [ ];

  # Without a console the journal is unreachable when the platform owns boot.
  services.journald.console = "/dev/console";

  # exe.dev enters a VM over SSH on 4722, a port its own base image serves
  # rather than sshd. Listening there too establishes whether that is all it
  # wants.
  services.openssh.ports = [
    22
    4722
  ];

  # The HTTPS proxy is the only ingress that does not depend on exe.dev
  # reaching in, so it carries the boot journal: if this answers, systemd came
  # up and ran units.
  systemd.services.boot-report = {
    description = "Serve the boot journal over HTTP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [
      pkgs.systemd
      pkgs.python3
    ];
    serviceConfig.ExecStart = pkgs.writeShellScript "boot-report" ''
      mkdir -p /var/lib/boot-report
      cd /var/lib/boot-report
      journalctl -b --no-pager > journal.txt 2>&1 || true
      systemctl list-units --failed --no-pager > failed.txt 2>&1 || true
      systemctl status --no-pager > status.txt 2>&1 || true
      exec python3 -m http.server 8000 --bind 0.0.0.0
    '';
  };
}
