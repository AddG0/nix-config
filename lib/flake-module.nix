{inputs, ...}: {
  # Don't try `_module.args.lib = ...` here — flake-parts doesn't
  # back-propagate that override to the `lib` arg sibling modules receive.
  # Consumers pull this via `inputs.self.lib` instead.
  flake.lib = inputs.nixpkgs.lib.extend (_self: _super: {
    custom = import ./default.nix {inherit (inputs.nixpkgs) lib;};
  });
}
