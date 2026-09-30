{customPkgs, ...}: {lib, ...}: {
  imports = [
    (lib.modules.importApply ./options.nix {inherit customPkgs;})
    ./config.nix
    ./blueprint.nix
  ];
}
