# modules/flake-module.nix - Custom NixOS, Darwin, and Home-manager modules
_: {
  flake = {
    nixosModules.default = {
      imports = [
        ./common
        ./common/nixos
        ./hosts
        ./hosts/nixos
      ];
    };

    darwinModules.default = {
      imports = [
        ./common
        ./common/darwin
        ./hosts
        ./hosts/darwin
      ];
    };

    homeModules.default = {
      imports = [
        ./common
        ./home
      ];
    };
  };
}
