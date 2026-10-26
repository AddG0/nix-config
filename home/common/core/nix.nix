{
  osConfig ? null,
  pkgs,
  self,
  lib,
  ...
}: {
  # A host with useGlobalPkgs hands home-manager its own nixpkgs; standalone homes build theirs.
  nixpkgs = lib.mkIf (!(osConfig.home-manager.useGlobalPkgs or false)) {
    overlays = builtins.attrValues self.overlays;
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "configurable-impure-env"
      ];
      warn-dirty = false;
    };
  };
}
