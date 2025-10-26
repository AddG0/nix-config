#############################################################
#
#  fenrir - VM MacOS Server
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

      #################### Optional Applications ####################
      "common/optional/darwin/applications/ghostty.nix"

      #################### Desktop ####################
    ])
  ];

  time.timeZone = "America/Chicago";

  hostSpec = {
    hostName = "fenrir";
    isDarwin = true;
    hostPlatform = "x86_64-darwin";
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = 5;
}
