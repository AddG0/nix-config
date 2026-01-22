{pkgs, ...}: {
  xdg.configFile = {
    "process-compose/theme.yaml".source = "${pkgs.themes.catppuccin.process-compose}/share/process-compose-catppuccin/catppuccin-mocha.yaml";
    # This is required to read the theme.yaml file
    "process-compose/settings.yaml".text = "theme: Custom Style";
  };
}
