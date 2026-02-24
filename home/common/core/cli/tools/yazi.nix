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
    shellWrapperName = "y";
    # Changing working directory when exiting Yazi
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    settings = {
      manager = {
        show_hidden = true;
        sort_dir_first = true;
      };
    };
  };

  xdg.configFile."yazi/theme.toml".source = lib.mkDefault "${nur-ryan4yin.packages.${pkgs.stdenv.hostPlatform.system}.catppuccin-yazi}/mocha.toml";
}
