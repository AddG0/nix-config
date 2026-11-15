# Makes plasma-manager's per-screen panels stick: its script seds appletsrc before Plasma has saved it.
{
  config,
  lib,
  ...
}: let
  appletsrc = "${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc";
in {
  programs.plasma.startup.desktopScript.panels = lib.mkIf (lib.any (panel: panel.screen != null) config.programs.plasma.panels) {
    # Emptied, not deleted, so a persisted symlink survives.
    preCommands = lib.mkForce ''
      if [ -f ${appletsrc} ]; then : > ${appletsrc}; fi
    '';
    # Plasma writes appletsrc as it stops, so the screen keys exist for sed to convert.
    postCommands = lib.mkForce ''
      systemctl --user stop plasma-plasmashell
      sed -i --follow-symlinks 's/^lastScreen\\x5b$i\\x5d=/lastScreen[$i]=/' ${appletsrc}
      systemctl --user start plasma-plasmashell
    '';
  };
}
