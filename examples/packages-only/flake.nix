{
  description = "Example: Using packages from nix-config without heavy dependencies";

  inputs = {
    # Only need nixpkgs and your packages - no Darwin, home-manager, etc!
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    addg-packages = {
      url = "github:addg0/nix-config";
      # This flake only needs nixpkgs thanks to flake-parts separation
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, addg-packages, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # Use packages from addg's config
    packages.${system} = {
      # Example: inherit specific packages you want
      inherit (addg-packages.packages.${system}) 
        # Add your package names here
        # themes
        # or whatever packages you expose
        ;

      # Or create a development environment with the packages
      myDevShell = pkgs.mkShell {
        buildInputs = with addg-packages.packages.${system}; [
          # Add the packages you want here
        ];
      };
    };

    # Clean development shell
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        # Your packages are available here without all the system config dependencies
      ];
    };
  };
} 