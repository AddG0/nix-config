{
  lib,
  pkgs,
  ...
}: {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.sketchybar" pkgs lib.platforms.darwin)];

  programs.sketchybar = {
    enable = true;
    configType = "lua";
    config = {
      source = ./config;
      recursive = true;
    };
    extraPackages = with pkgs; [
      jq
      nowplaying-cli
    ];
    extraLuaPackages = ps:
      with ps; [
        luafilesystem
      ];
  };

  home.packages = [
    pkgs.sketchybar-app-font
  ];
}
