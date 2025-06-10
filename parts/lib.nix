# parts/lib.nix - Extended lib with custom functions
{inputs, ...}: {
  flake = {
    # Extend lib with lib.custom
    # NOTE: This approach allows lib.custom to propagate into home-manager
    # see: https://github.com/nix-community/home-manager/pull/3454
    lib = inputs.nixpkgs.lib.extend (self: super: {
      custom = import ../lib {inherit (inputs.nixpkgs) lib;};
    });
  };
}
