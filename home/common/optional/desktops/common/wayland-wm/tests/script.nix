# session-dpms runs the entry for the session's compositor, whatever else the host has.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  dpms = import ../_session-dpms.nix {
    inherit lib pkgs;
    commands = {
      Hyprland = {
        off = "echo hyprland-off";
        on = "echo hyprland-on";
      };
      niri = {
        off = "echo niri-off";
        on = "echo niri-on";
      };
    };
  };
in
  harness.bats "session-dpms-test" [./session-dpms.bats] {
    sessionDpms = lib.getExe dpms;
  }
