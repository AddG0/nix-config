# hyprmoncfg: monitor layout editor with profiles keyed by make/model/serial, for laptops that dock.
{
  config,
  lib,
  pkgs,
  ...
}: let
  monitorsConf = "${config.xdg.configHome}/hypr/hyprmoncfg-monitors.conf";
in
  lib.mkIf (config.hostSpec.hostType == "laptop") {
    home.packages = [pkgs.hyprmoncfg];

    # Hyprland's source directive errors on a missing file before the first apply.
    home.activation.createHyprmoncfgMonitorsConf = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -f ${lib.escapeShellArg monitorsConf} ]; then
        run mkdir -p ${lib.escapeShellArg (dirOf monitorsConf)}
        run touch ${lib.escapeShellArg monitorsConf}
      fi
    '';

    # hyprmoncfg appends this to hyprland.conf itself, which is read-only here; sourced last so its layout wins.
    wayland.windowManager.hyprland.extraConfig = ''
      source = ${monitorsConf}
    '';
  }
