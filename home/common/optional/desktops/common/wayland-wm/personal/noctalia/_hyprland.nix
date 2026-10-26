{
  config,
  lib,
  ...
}: {
  wayland.windowManager.hyprland = {
    settings.bind = [
      # SUPER+C / SUPER+N open the calendar and notifications control-center tabs.
      "SUPER,c,exec,${lib.getExe config.programs.noctalia.package} msg panel-toggle control-center calendar"
      "SUPER,n,exec,${lib.getExe config.programs.noctalia.package} msg panel-toggle control-center notifications"
    ];

    settings.layerrule = [
      # Noctalia animates its own panels; Hyprland's layersIn slide would fly them in from the edge.
      "no_anim on, match:namespace ^noctalia-(attached-panel|panel)$"
      # Xray blurs only the wallpaper, so bar and attached panel share a backdrop and meet without a seam.
      "xray on, match:namespace ^noctalia-(bar-main|attached-panel)$"
    ];
  };
}
