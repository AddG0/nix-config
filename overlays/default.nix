# Orchestration only: auto-import the categorized overlay files and compose
# them. Each is a plain overlay that self-guards its own platform.
{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;

  # Recursively import every .nix file under `dir` as an overlay.
  importOverlays = dir:
    lib.concatLists (lib.mapAttrsToList (
        name: type:
          if type == "directory"
          then importOverlays (dir + "/${name}")
          else if lib.hasSuffix ".nix" name
          then [(import (dir + "/${name}") {inherit inputs;})]
          else []
      )
      (builtins.readDir dir));
in {
  default = lib.composeManyExtensions (
    # nix-vscode-extensions provides the vscode-marketplace* namespaces that the
    # development/vscode patches extend, so it must compose first.
    [inputs.nix-vscode-extensions.overlays.default]
    ++ [
      (import ./sets.nix {inherit inputs;})
      (import ./packages.nix {inherit inputs;})
    ]
    ++ importOverlays ./development
    ++ importOverlays ./desktop
    ++ importOverlays ./media
    ++ importOverlays ./system
  );
}
