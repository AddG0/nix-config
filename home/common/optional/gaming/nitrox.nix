{inputs, ...}: {
  imports = [inputs.nitrox-nix.homeManagerModules.default];
  programs.nitrox.enable = true;
}
