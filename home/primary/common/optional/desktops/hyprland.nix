# Which workspace each app opens on under Hyprland; hosts pin workspaces to monitors themselves.
{
  wayland.windowManager.hyprland.settings.windowrule = [
    "workspace 3 silent, match:class ^(slack)$"
    "workspace 3 silent, match:title .*([Dd]iscord|[Ll]egcord).*"
    "workspace 2 silent, match:class ^(zen(-beta)?)$"
    "workspace 6 silent, match:class ^([Ss]team)$"
    # Updater dialog maps with an empty class, so the rule above misses it.
    "workspace 6 silent, match:class ^$, match:title ^Steam$"
  ];
}
