{
  config,
  lib,
  ...
}:
lib.mkIf config.wayland.windowManager.hyprland.enable {
  wayland.windowManager.hyprland = {
    settings.bind = [
      "SUPER,space,exec,walker"
      # SUPER+C / SUPER+N open the calendar and notifications control-center tabs.
      "SUPER,c,exec,${lib.getExe config.programs.noctalia.package} msg panel-toggle control-center calendar"
      "SUPER,n,exec,${lib.getExe config.programs.noctalia.package} msg panel-toggle control-center notifications"
    ];

    settings.layerrule = [
      # Scale up in place rather than slide from an edge. Only the style can be
      # overridden per-layer — timing/curve still come from the global layersIn.
      "animation popin 88%, match:namespace walker"
      # Noctalia animates its own panels; Hyprland's layersIn slide would fly them in from the edge.
      "no_anim on, match:namespace ^noctalia-(attached-panel|panel)$"
    ];
  };
}
