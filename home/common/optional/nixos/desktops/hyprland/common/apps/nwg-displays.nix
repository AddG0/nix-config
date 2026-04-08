{
  hostSpec,
  lib,
  pkgs,
  ...
}:
lib.mkIf (hostSpec.hostType == "laptop") {
  home.packages = let
    nwgDisplaysGuarded = pkgs.writeShellScriptBin "nwg-displays" ''
      exec ${pkgs.systemd}/bin/systemd-run \
        --user \
        --scope \
        --collect \
        --property=MemoryHigh=1G \
        --property=MemoryMax=2G \
        ${pkgs.nwg-displays}/bin/nwg-displays "$@"
    '';
  in [
    (lib.hiPrio nwgDisplaysGuarded)
    pkgs.nwg-displays
  ];

  # Create an empty monitors.conf if nwg-displays hasn't run yet,
  # so Hyprland's source directive doesn't error on first boot.
  home.activation.createMonitorsConf = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/.config/hypr/monitors.conf" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.config/hypr"
      $DRY_RUN_CMD touch "$HOME/.config/hypr/monitors.conf"
    fi
  '';

  wayland.windowManager.hyprland = {
    # Sourced last so nwg-displays overrides declarative monitor rules
    extraConfig = ''
      source = ~/.config/hypr/monitors.conf
    '';
  };
}
