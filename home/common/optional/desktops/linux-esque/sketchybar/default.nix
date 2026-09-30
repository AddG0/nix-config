{pkgs, ...}: {
  programs.sketchybar = {
    enable = true;
    configType = "lua";
    config = {
      source = ./config;
      recursive = true;
    };
    extraPackages = with pkgs; [
      jq
      aerospace
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
