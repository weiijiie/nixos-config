# Variant of the hub for exe.dev, which boots a VM from a container image.
#
# The platform owns the kernel and the block device, so NixOS's bootloader and
# firewall layers do not apply; docker-image.nix turns them off and marks the
# system as containerized. The image only seeds the disk at creation, so updates
# after that are ordinary `nixos-rebuild switch --target-host` runs.
{ modulesPath, lib, ... }:
{
  imports = [ "${modulesPath}/virtualisation/docker-image.nix" ];

  boot.loader.grub.enable = lib.mkForce false;

  # A container has no channels, and NIX_PATH reaches /etc/pam/environment,
  # which would pull a whole nixpkgs checkout into the image.
  nix.nixPath = lib.mkForce [ ];

  # Without a console the journal is unreachable when the platform owns boot.
  services.journald.console = "/dev/console";
}
