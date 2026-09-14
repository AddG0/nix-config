#############################################################
#
#  AWS EC2 Instance
#  NixOS running on Amazon Web Services (EC2 / AMI)
#
#  Uses amazon-image.nix so the EFI bootloader settings persist at
#  runtime and the amazon image variant produces a registrable AMI.
#  Generic base meant to be extended (mirrors the gce host), NOT a
#  concrete machine.
#  Build: `just build-image ec2 amazon`.
#
###############################################################
{
  lib,
  modulesPath,
  ...
}: {
  imports = lib.flatten [
    # EC2 image + runtime config (amazon-init guest agent, ena driver, grub, the
    # config.system.build.images.amazon target, and the `ec2.efi` option below)
    "${modulesPath}/virtualisation/amazon-image.nix"

    #################### Misc Inputs ####################
    (map lib.custom.relativeToHosts (map (f: "common/optional/${f}") [
      "nixos/services/openssh.nix"
    ]))
  ];

  hostSpec = {
    hostName = lib.mkDefault "ec2";
    hostPlatform = lib.mkDefault "x86_64-linux";
    hostType = "server";
    disableSops = true;
    isMinimal = builtins.getEnv "NIXOS_MINIMAL" == "true";
  };

  # Build a UEFI AMI, not the default legacy-BIOS image. This single flag drives
  # everything coherently in amazon-image.nix: grub-EFI with efiInstallAsRemovable
  # (boots via /EFI/BOOT/BOOTX64.EFI, no NVRAM writes — required for an AMI), an
  # ESP (partitionTableType "efi"), and amiBootMode "uefi". Register the AMI as
  # uefi to match, or an instance drops to the UEFI shell in a reboot loop.
  ec2.efi = true;

  # Size the image to the closure (+ESP) instead of amazon-image.nix's hardcoded
  # 4 GiB (lib.mkOverride 1490 (4*1024)) — that barely fits and, once ec2.efi
  # carves out the ESP, the store copy dies with "No space left on device".
  # "auto" tracks the closure and yields a smaller (faster-importing) snapshot;
  # the instance's EBS volume + growfs expand root on first boot regardless.
  virtualisation.diskSize = lib.mkDefault "auto";

  # amazon-image.nix already provisions networking via DHCP; unlike the gce host
  # we deliberately do NOT enable NetworkManager (it would fight amazon-init's
  # cloud networking on a headless instance). IPv6 is on — AWS supports it.
  networking.enableIPv6 = true;

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  services.resolved.enable = true;

  time.timeZone = "America/Chicago";

  # Amazon Time Sync Service — the link-local NTP endpoint every EC2 instance can
  # reach with no egress, the AWS analog of GCE's metadata NTP.
  services.timesyncd = {
    enable = true;
    servers = ["169.254.169.123"];
  };
}
