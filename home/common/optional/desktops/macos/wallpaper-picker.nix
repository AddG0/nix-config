# macOS counterpart of the Hyprland SUPER+W picker; picks from the same wallhaven set wallpaper-cycle rotates through.
{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  images = pkgs.linkFarm "wallhaven-wallpapers" (import ../_wallhaven.nix {inherit pkgs;});
  c = config.lib.stylix.colors.withHashtag;

  launcher = pkgs.writeShellApplication {
    name = "wallpaper-picker-launch";
    runtimeInputs = [customPkgs.wallpaper-picker-mac];
    text = ''
      export WP_DIR=${images}
      export WP_BG=${lib.escapeShellArg c.base00}
      export WP_FG=${lib.escapeShellArg c.base05}
      export WP_BORDER=${lib.escapeShellArg c.base03}
      export WP_ACCENT=${lib.escapeShellArg c.base0D}
      exec wallpaper-picker "$@"
    '';
  };
in {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.wallpaper-picker" pkgs lib.platforms.darwin)];

  services.skhd.config = ''
    alt - w : ${lib.getExe launcher}
  '';

  programs.omniwm.settings.appRules = [
    {
      bundleId = "local.wallpaper-picker";
      layout = "float";
    }
  ];
}
