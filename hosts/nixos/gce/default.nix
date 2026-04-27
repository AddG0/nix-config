#############################################################
#
#  GCP Compute Engine Instance
#  NixOS running on Google Cloud Platform
#
#  Uses google-compute-image.nix so the EFI bootloader settings
#  (grub efiSupport, ESP /boot mount) persist at runtime — required
#  because we build a UEFI image for Shielded VM support.
#  Build: `just build-image gce google-compute`.
#
###############################################################
{
  lib,
  modulesPath,
  ...
}: {
  imports = lib.flatten [
    # GCE image + runtime config (declares virtualisation.googleComputeImage.efi
    # and wires the EFI bootloader when enabled)
    "${modulesPath}/virtualisation/google-compute-image.nix"

    #################### Misc Inputs ####################
    (map lib.custom.relativeToHosts (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        "nixos/services/openssh.nix"
      ])
    ))
  ];

  hostSpec = {
    hostName = "gce";
    hostPlatform = "x86_64-linux";
    hostType = "server";
    disableSops = true;
    isMinimal = builtins.getEnv "NIXOS_MINIMAL" == "true";
  };

  # Build a UEFI image so the VM can run as a Shielded VM (vTPM +
  # integrity monitoring + secure boot). Switches grub to EFI mode and
  # adds an ESP at /dev/disk/by-label/ESP mounted at /boot.
  virtualisation.googleComputeImage.efi = true;

  # Override to match GCE module expectation (it doesn't use mkDefault)
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # Disable OS Login - use traditional SSH keys instead of GCP IAM
  security.googleOsLogin.enable = lib.mkForce false;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = true; # GCP supports IPv6
  };

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  services.resolved.enable = true;

  time.timeZone = "America/Chicago";

  # NTP configuration for GCP (use Google's NTP servers)
  services.timesyncd = {
    enable = true;
    servers = ["metadata.google.internal"];
  };
}
