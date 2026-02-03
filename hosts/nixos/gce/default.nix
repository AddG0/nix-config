#############################################################
#
#  GCP Compute Engine Instance
#  NixOS running on Google Cloud Platform
#
#  NOTE: This host does NOT use disko because the GCE format
#  from nixos-generators includes google-compute-config.nix
#  which handles disk/filesystem configuration automatically.
#
###############################################################
{
  lib,
  modulesPath,
  ...
}: {
  imports = lib.flatten [
    # GCE config from nixpkgs - provides filesystem, bootloader, and cloud services
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
