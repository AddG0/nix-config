# overlays/flake-module.nix - Nixpkgs overlays
{inputs, ...}: {
  flake = {
    # Export overlays for external use
    # Usage: import nixpkgs { overlays = [ inputs.yourflake.overlays.default ]; }
    overlays = import ./default.nix {inherit inputs;};
  };
}
