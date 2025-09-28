{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in {
  imports = lib.flatten [
    inputs.spicetify-nix.homeManagerModules.spicetify
  ];

  programs.spicetify = {
    enable = true;
    theme = lib.mkDefault spicePkgs.themes.catppuccin;
    colorScheme = lib.mkDefault config.desktops.catppuccin.flavor;
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      shuffle # shuffle+ (special characters are sanitized out of extension names)
      #  loopyLoop
      #  bookmark
    ];
  };

  home.packages = with pkgs; [
    spicetify-cli
  ];
}
