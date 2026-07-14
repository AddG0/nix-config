# Orchestration only: auto-import the categorized overlay files and compose
# them. `common` overlays apply everywhere; overlays under `nixos`/`darwin` are
# auto-guarded to that platform, mirroring modules/common/{nixos,darwin}.
{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;

  # Recursively import every .nix file under `dir` as an overlay. Returns []
  # for a missing directory so platform folders can be empty (only .gitkeep).
  # An `input-packages` subdir is composed before its siblings so overlays that
  # override input-derived packages (e.g. desktop patches on `noctalia`) see
  # those packages in `prev`.
  importOverlays = dir:
    lib.optionals (builtins.pathExists dir) (
      let
        entries = builtins.readDir dir;
        importEntry = name:
          if entries.${name} == "directory"
          then importOverlays (dir + "/${name}")
          else if lib.hasSuffix ".nix" name
          then [(import (dir + "/${name}") {inherit inputs;})]
          else [];
        ordered =
          lib.optional (entries ? input-packages) "input-packages"
          ++ builtins.filter (n: n != "input-packages") (builtins.attrNames entries);
      in
        lib.concatLists (map importEntry ordered)
    );

  # Wrap platform-specific overlays (nixos/darwin) so their attributes only
  # apply on the matching platform. Files in those folders can then stay
  # platform-agnostic instead of repeating `lib.optionalAttrs` guards.
  guardPlatform = isPlatform: overlays:
    map (overlay: final: prev:
      lib.optionalAttrs (isPlatform prev.stdenv) (overlay final prev))
    overlays;
in {
  default = lib.composeManyExtensions (
    # nix-vscode-extensions provides the vscode-marketplace* namespaces that the
    # common/development/vscode patches extend, so it must compose first.
    [inputs.nix-vscode-extensions.overlays.default]
    ++ [
      (import ./sets.nix {inherit inputs;})
      (import ./packages.nix {inherit inputs;})
    ]
    ++ importOverlays ./common
    ++ guardPlatform (stdenv: stdenv.isLinux) (importOverlays ./nixos)
    ++ guardPlatform (stdenv: stdenv.isDarwin) (importOverlays ./darwin)
    # Temporary workarounds for nixpkgs builds broken on the current pin. Comment
    # this line out to disable them all — e.g. to check whether a `nix flake
    # update` has made them redundant.
    ++ importOverlays ./flake-update-workarounds
  );
}
