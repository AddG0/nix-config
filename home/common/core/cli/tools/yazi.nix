{
  pkgs,
  lib,
  nur-ryan4yin,
  ...
}: {
  # terminal file manager
  programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    # Changing working directory when exiting Yazi
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      manager = {
        show_hidden = true;
        sort_dir_first = true;
      };
    };
  };

  xdg.configFile."yazi/theme.toml".source = lib.mkDefault "${nur-ryan4yin.packages.${pkgs.system}.catppuccin-yazi}/mocha.toml";
}
