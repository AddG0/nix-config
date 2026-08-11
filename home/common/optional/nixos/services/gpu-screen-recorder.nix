#
# GPU Screen Recorder replay buffer.
#
# Importing hosts must set `services.gpu-screen-recorder.display` (e.g.
# `"portal"` to capture via xdg-desktop-portal — recommended for HDR/10-bit
# monitors since direct capture there produces oversaturated colors) and
# typically `matchMonitorName` so the smart xdph picker can auto-select the
# right monitor without showing a dialog.
# https://wiki.hyprland.org/Configuring/Monitors/#10-bit-support
#
{
  pkgs,
  lib,
  ...
}: let
  # GSR matches pipewire node.name exactly; VLC's embeds its version, minus nixpkgs' -N suffix.
  vlcAudioName = "VLC media player (LibVLC ${lib.head (lib.splitString "-" pkgs.vlc.version)})";

  # Moves each saved clip into a subdirectory named after the running Steam game,
  # or Minecraft/<instance> for PrismLauncher.
  sortClipScript = pkgs.writeShellApplication {
    name = "gsr-sort-clip";
    runtimeInputs = with pkgs; [coreutils gnugrep gnused];
    text = ''
      file="''${1:?usage: gsr-sort-clip <filepath> [type]}"
      [ -f "$file" ] || exit 0

      # First value matching an env-var regex across all running processes.
      # -z splits on NUL so values keep any spaces.
      proc_env() {
        grep -aohz "$1" /proc/[0-9]*/environ 2>/dev/null \
          | tr '\0' '\n' | cut -d= -f2- | head -1 || true
      }

      # A slash in a game or instance name would fork the path.
      sanitize() {
        printf '%s' "$1" | tr '/' '_'
      }

      # SteamAppId is in the env of every process Steam launches a game in (0 for
      # non-Steam shortcuts) — covers Proton, and ignores which window is focused.
      appid=$(proc_env 'SteamAppId=[1-9][0-9]*')
      # PrismLauncher's INST_NAME is the display name, not the dir id.
      inst=$(proc_env 'INST_NAME=.*')

      if [ -n "$appid" ]; then
        name=$(sed -n 's|^[[:space:]]*"name"[[:space:]]*"\(.*\)"|\1|p' \
          "$HOME/.steam/root/steamapps/appmanifest_$appid.acf" 2>/dev/null | head -1 || true)
        subdir=$(sanitize "''${name:-AppID $appid}")
      elif [ -n "$inst" ]; then
        # Instances are profiles rather than separate games, so keep them together.
        subdir="Minecraft/$(sanitize "$inst")"
      else
        echo "gsr-sort-clip: no game running, leaving clip in place" >&2
        exit 0
      fi

      dir="$(dirname "$file")/$subdir"
      mkdir -p "$dir"
      mv -- "$file" "$dir/"
      echo "gsr-sort-clip: $subdir <- $(basename "$file")"
    '';
  };
in {
  services.gpu-screen-recorder = {
    enable = true;
    postRecordSeconds = 10;
    postSaveScript = sortClipScript;
    # Everything but spotify and vlc
    audioDevices = ["app-inverse:spotify|app-inverse:${vlcAudioName}|default_input"];
  };
}
