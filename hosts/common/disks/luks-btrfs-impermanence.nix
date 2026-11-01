# LUKS + btrfs whose root subvolume is replaced each boot; see ADR 0016.
{
  config,
  utils,
  pkgs,
  disk,
  ...
}: let
  cryptName = "crypted";
  cryptDevice = "/dev/mapper/${cryptName}";
in {
  disko.devices.disk.main = {
    type = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          # systemd-boot copies a kernel and initrd per generation here.
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = cryptName;
            # Read only while formatting; scripts/bootstrap/bootstrap-nixos.sh writes it.
            passwordFile = "/tmp/disko-password";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = ["-f"];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@persist" = {
                  mountpoint = config.hostSpec.persistFolder;
                  mountOptions = ["compress=zstd" "noatime"];
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems.${config.hostSpec.persistFolder}.neededForBoot = true;

  # The VM boots without the LUKS disk, so this would wait out the device timeout.
  virtualisation.vmVariant.boot.initrd.systemd.services.rollback-root.enable = false;

  boot.initrd.systemd = {
    initrdBin = [pkgs.findutils];
    services.rollback-root = {
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      wantedBy = ["initrd.target"];
      before = ["sysroot.mount"];
      requires = ["${utils.escapeSystemdPath cryptDevice}.device"];
      after = [
        "${utils.escapeSystemdPath cryptDevice}.device"
        # Lets a hibernation image resume before the root it belongs to moves.
        "local-fs-pre.target"
      ];
      script = import ./_rollback-root.nix {
        mountDir = "/btrfs_tmp";
        device = cryptDevice;
      };
    };
  };
}
