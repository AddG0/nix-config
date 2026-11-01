# specialArgs for every nixosConfiguration, and for checks that build a host the same way.
inputs: {
  inherit inputs;
  inherit (inputs) self nix-secrets nixvirt;
  inherit (inputs.self) lib;
  isDarwin = false;
}
