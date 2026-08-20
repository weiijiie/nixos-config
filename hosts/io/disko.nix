# Disk layout for the hub, applied by nixos-anywhere at install time.
#
# Provider-agnostic: GPT with both a BIOS boot partition and an ESP, so the same
# layout boots whether the VPS gives us legacy BIOS or UEFI. GRUB is installed
# for BIOS here because that is what the x86 cloud providers still default to;
# switching to UEFI is a change to this file, not a repartition.
{ lib, ... }:
let
  # virtio disks appear as /dev/vda on some providers.
  disk = "/dev/sda";
in
{
  # disko points GRUB at the disk carrying the EF02 partition below.
  boot.loader.grub.enable = true;

  disko.devices.disk.main = {
    device = disk;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };

        esp = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  # A 4 GB box with no swap partition; compressed RAM covers the spikes.
  zramSwap.enable = lib.mkDefault true;
}
