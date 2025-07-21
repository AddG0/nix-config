{lib, inputs, ...}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];
}
