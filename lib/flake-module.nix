# lib/flake-module.nix - Extended lib with custom functions
{inputs, ...}: {
  # Extend lib with lib.custom
  # NOTE: This approach allows lib.custom to propagate into home-manager
  # see: https://github.com/nix-community/home-manager/pull/3454
  _module.args.lib = inputs.nixpkgs.lib.extend (_self: _super: {
    custom = import ./default.nix {inherit (inputs.nixpkgs) lib;};
  });

  flake = {
    # Extend lib with lib.custom
    # NOTE: This approach allows lib.custom to propagate into home-manager
    # see: https://github.com/nix-community/home-manager/pull/3454
    lib = inputs.nixpkgs.lib.extend (_self: _super: {
      custom = import ./default.nix {inherit (inputs.nixpkgs) lib;};
    });
  };
}
