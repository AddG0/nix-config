# Overlays module - for package modifications and extensions
{ inputs, ... }:

{
  flake = {
    # Custom overlays for package modifications
    overlays = import ../overlays { inherit inputs; };
  };

  # Apply overlays to perSystem pkgs
  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        # Apply our custom overlays (but avoid infinite recursion)
        # inputs.self.overlays.default
      ];
      config = {
        # Allow unfree packages if needed for packages
        allowUnfree = true;
      };
    };
  };
} 