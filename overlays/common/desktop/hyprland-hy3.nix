# Pin Hyprland and hy3 in lockstep from the hy3 flake. nixpkgs ships hyprland
# and hyprlandPlugins.hy3 out of sync (e.g. hyprland 0.55.2 vs hy3 0.55.0), so
# the plugin refuses to load with a version-mismatch error. hy3 builds against
# the exact Hyprland commit it pins, so sourcing pkgs.hyprland from hy3's own
# hyprland input — rather than the other way round — guarantees they match.
{inputs, ...}: final: prev: let
  inherit (final.stdenv.hostPlatform) system;
in
  prev.lib.optionalAttrs prev.stdenv.isLinux {
    hyprland = inputs.hy3.inputs.hyprland.packages.${system}.hyprland;
    hyprlandPlugins =
      (prev.hyprlandPlugins or {})
      // {
        hy3 = inputs.hy3.packages.${system}.hy3;
      };
  }
