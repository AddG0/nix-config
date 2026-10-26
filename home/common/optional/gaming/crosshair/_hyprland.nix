{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  # The active workspace's monitor is where the crosshair is wanted; fall back to the focused one.
  focusedOutput = pkgs.writeShellApplication {
    name = "hypr-focused-output";
    runtimeInputs = [config.wayland.windowManager.hyprland.package pkgs.jq];
    text = ''
      mon=$(hyprctl activeworkspace -j | jq -r '.monitor // empty')
      if [ -z "$mon" ]; then
        mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
      fi
      echo "$mon"
    '';
  };
  toggle = import ./_toggle.nix {
    inherit lib pkgs customPkgs;
    focusedOutput = lib.getExe focusedOutput;
  };
in {
  wayland.windowManager.hyprland.settings = {
    bind = ["SUPERSHIFT,c,exec,${lib.getExe toggle}"];
    # - blur off: avoid Hyprland blurring the layer (see-through smear).
    # - animation none: each reload destroys/recreates the surface; without
    #   this, Hyprland slides it in from the screen edge on every monitor
    #   switch.
    layerrule = [
      "blur off, match:namespace wlcrosshair"
      "animation none, match:namespace wlcrosshair"
    ];
  };
}
