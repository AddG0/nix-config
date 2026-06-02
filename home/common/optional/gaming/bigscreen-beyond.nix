# Bigscreen Beyond Utility per-user wiring.
#
# Pre-fills the Utility's "SteamVR path" setting so its "invalid SteamVR
# folder" check passes against a Windows-style stub install at
# ~/steamvr_win. The Utility is a Windows app under Proton; it expects a
# Windows SteamVR install layout to validate its path.
#
# SteamVR driver discovery is intentionally NOT touched here: when the
# Beyond Utility (Steam app 2467050) is installed, Steam registers it via
# openvrpaths.vrpath's `external_drivers` field, and that's the path
# SteamVR-for-Linux loads. Symlinking the Beyond Driver into SteamVR's
# `drivers/` dir shadows that external entry with a non-loadable Windows
# DLL driver and causes SteamVR to skip the real one.
#
# To populate ~/steamvr_win (one-time, ~500 MB):
# mkdir -p ~/steamvr_win && NIXPKGS_ALLOW_UNFREE=1 nix run nixpkgs#steamcmd --impure -- +@ShutdownOnFailedCommand 1 +@sSteamCmdForcePlatformType windows +force_install_dir "$HOME/steamvr_win" +login anonymous +app_update 250820 validate +quit
#
# Refs:
#   - https://github.com/ValveSoftware/SteamVR-for-Linux/issues/610
#   - https://wiki.vronlinux.org/docs/hardware/bigscreen-beyond/
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = config.home.username;
in {
  home.activation.bigscreenBeyondUtilitySteamVRPath = lib.hm.dag.entryAfter ["writeBoundary"] ''
    SETTINGS="$HOME/.local/share/Steam/steamapps/common/Bigscreen Beyond Driver/bin/beyond_settings.json"
    TARGET='Z:\home\${user}\steamvr_win'
    if [ -f "$SETTINGS" ]; then
      current=$(${pkgs.jq}/bin/jq -r '.steamvr_path' "$SETTINGS")
      if [ "$current" != "$TARGET" ]; then
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq --arg p "$TARGET" '.steamvr_path = $p' "$SETTINGS" > "$tmp"
        run mv "$tmp" "$SETTINGS"
      fi
    fi
  '';
}
