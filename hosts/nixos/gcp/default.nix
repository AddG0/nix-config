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
  ...
}: {
  imports = lib.flatten [
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
    hostName = "gcp";
    hostPlatform = "x86_64-linux";
    hostType = "server";
    disableSops = true;
  };

  # Override to match GCE module expectation (it doesn't use mkDefault)
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # Disable OS Login - use traditional SSH keys instead of GCP IAM
  security.googleOsLogin.enable = lib.mkForce false;

  networking = {
    networkmanager.enable = true;
    enableIPv6 = true; # GCP supports IPv6
  };

  time.timeZone = "America/Chicago";

  # NTP configuration for GCP (use Google's NTP servers)
  services.timesyncd = {
    enable = true;
    servers = ["metadata.google.internal"];
  };
}
