#############################################################
#
#  ghost - Main Desktop
#  MacOS running on M4 Max, 128GB RAM
#
###############################################################
{
  inputs,
  lib,
  config,
  pkgs,
  isDarwin,
  ...
}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHosts [
      #################### Required Configs ####################
      "common/core"

      #################### Host-specific Optional Configs ####################
      "common/optional/darwin/ghostty"

      #################### Optional Applications ####################
      "common/optional/darwin/applications/jprofiler.nix"

      #################### Desktop ####################
    ])
  ];

  time.timeZone = "America/Chicago";

  hostSpec = {
    username = lib.mkForce "shqadmin";
    handle = lib.mkForce "shqadmin";
    hostName = "mini";
    isDarwin = true;
    hostPlatform = "x86_64-darwin";
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = 5;
}
