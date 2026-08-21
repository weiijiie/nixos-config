# Variant of the hub for exe.dev. The platform supplies the kernel, seeds a
# persistent disk from a container image, and runs its own shim
# (/exe.dev/bin/exe-init) before handing PID 1 to /init: the shim configures
# the NIC, routes, DNS, hostname and hosts file, and serves SSH with an
# embedded daemon. This follows the reference config in the exe.dev repo
# (nix/configuration.nix); the image itself is assembled in pkgs/io-image.nix.
{
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  # exe.dev's ssh daemon supplies a conventional PATH, so login shells go
  # through a wrapper that adds the NixOS system profile. /sw is the image's
  # link to the system profile, for shells spawned before first activation.
  exeShell = pkgs.writeShellScriptBin "exe-shell" ''
    if [ -x /run/current-system/sw/bin/zsh ]; then
      shell=/run/current-system/sw/bin/zsh
    else
      shell=/sw/bin/zsh
    fi

    export PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    exec "$shell" "$@"
  '';
in
{
  imports = [ "${modulesPath}/profiles/docker-container.nix" ];

  installer.cloneConfig = false;

  # Flakes only; a copy of the nixpkgs channel would add ~400 MB to the image.
  system.installer.channel.enable = false;

  # The platform owns the boot path and the disk; disko's partitions and
  # mounts describe hardware that does not exist here.
  boot.loader.grub.enable = lib.mkForce false;
  disko.devices = lib.mkForce { };
  zramSwap.enable = lib.mkForce false;
  services.qemuGuest.enable = lib.mkForce false;

  # exe-init owns the network and the SSH ingress; a second sshd or a DHCP
  # client would race it.
  networking.hostName = lib.mkForce "";
  networking.useDHCP = false;
  networking.useHostResolvConf = false;
  networking.resolvconf.enable = false;
  environment.etc.hosts.enable = false;
  networking.firewall.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;

  # exe.dev injects and serves SSH public keys outside the NixOS OpenSSH
  # configuration, so NixOS cannot see the login method at evaluation time.
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;
  users.users.root.shell = "/bin/exe-shell";
  users.users.wj = {
    # The image seeds /etc/passwd with this uid for exe-init's sshd; keep
    # activation's assignment identical.
    uid = 1000;
    shell = "/bin/exe-shell";
  };
  security.sudo.wheelNeedsPassword = false;

  # exe-init's embedded sshd requires this privilege-separation account to
  # remain present after NixOS activation rewrites /etc/passwd.
  users.groups.sshd = { };
  users.users.sshd = {
    isSystemUser = true;
    group = "sshd";
    home = "/var/empty";
  };

  environment.systemPackages = [ exeShell ];

  system.activationScripts.exeDevShell = lib.stringAfter [ "users" ] ''
    install -Dm0755 ${exeShell}/bin/exe-shell /bin/exe-shell
  '';

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

  # NIX_PATH reaches /etc/pam/environment, which would pull a whole nixpkgs
  # checkout into the image.
  nix.nixPath = lib.mkForce [ ];

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
