# Disk configuration for dual-booting NixOS and Windows
# This configuration preserves existing Windows partitions
{
  lib,
  disk ? "/dev/vda",
  withSwap ? false,
  swapSize,
  config,
  ...
}: {
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        # Use disk ID instead of device name for stability
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition (ESP) that already exists from Windows
            # We just mount it but don't format it
            ESP = {
              name = "ESP";
              type = "EF00"; # EFI system partition type
              # Don't specify size or start to use existing partition
              # Size and location are preserved
              content = {
                type = "filesystem";
                format = false; # Don't format the existing ESP
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
              # Note: This will find and use the existing ESP partition without modifying it
            };

            # NixOS partition (BTRFS)
            # Start after Windows partitions (typically Windows uses ~500GB)
            nixos = {
              name = "nixos";
              # This is the key - start after Windows partitions
              # Adjust this value based on your Windows partition size
              start = "500G";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # Override existing partition
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@persist" = {
                    mountpoint = "${config.hostSpec.persistFolder}";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@swap" = lib.mkIf withSwap {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "${swapSize}G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
