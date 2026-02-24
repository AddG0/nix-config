{
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs.nix-jetbrains-plugins.lib) pluginsForIde;
  withPlugins = ide: pluginIds:
    pkgs.jetbrains.plugins.addPlugins ide (builtins.attrValues (pluginsForIde pkgs ide pluginIds));
in {
  home.packages = with pkgs;
    [
      (withPlugins jetbrains.idea ["nix-idea" "com.github.catppuccin.jetbrains" "net.ashald.envfile"])
      jetbrains.pycharm
      (withPlugins jetbrains.datagrip ["com.github.catppuccin.jetbrains"])
      jetbrains.webstorm

      # jetbrains.phpstorm
      # vscode
      code-cursor
    ]
    ++ (
      if pkgs.stdenv.isLinux
      then [
        android-studio
      ]
      else []
    );
}
