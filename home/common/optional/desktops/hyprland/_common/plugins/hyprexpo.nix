{
  pkgs,
  config,
  ...
}: let
  c = config.lib.stylix.colors;
in {
  wayland.windowManager.hyprland = {
    plugins = [pkgs.hyprlandPlugins.hyprexpo];
    settings = {
      "plugin:hyprexpo" = {
        columns = 3;
        gap_size = 10;
        bg_col = "rgba(${c.base00}ff)";
        workspace_method = "center current";
      };

      bind = [
        "SUPER,grave,hyprexpo:expo,toggle"
      ];
    };
  };
}
