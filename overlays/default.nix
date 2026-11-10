# Orchestration only: auto-import the categorized overlay files and compose
# them. `common` overlays apply everywhere; overlays under `nixos`/`darwin` are
# auto-guarded to that platform.
{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;

  overlayFiles = import ./overlay-files.nix {inherit lib;};
  importAll = map (file: import file {inherit inputs;});

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
    ++ importAll overlayFiles.common
    ++ guardPlatform (stdenv: stdenv.hostPlatform.isLinux) (importAll overlayFiles.nixos)
    ++ guardPlatform (stdenv: stdenv.hostPlatform.isDarwin) (importAll overlayFiles.darwin)
    # Temporary workarounds for nixpkgs builds broken on the current pin. Comment
    # this line out to disable them all — e.g. to check whether a `nix flake
    # update` has made them redundant.
    ++ importAll overlayFiles.workarounds
  );
}
