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
{pkgs, ...}: let
  # Moves each saved clip into a subdirectory named after the running Steam game.
  sortClipScript = pkgs.writeShellApplication {
    name = "gsr-sort-clip";
    runtimeInputs = with pkgs; [coreutils gnugrep gnused];
    text = ''
      file="''${1:?usage: gsr-sort-clip <filepath> [type]}"
      [ -f "$file" ] || exit 0

      # SteamAppId is in the env of every process Steam launches a game in (0 for
      # non-Steam shortcuts) — covers Proton, and ignores which window is focused.
      appid=$(grep -aohz 'SteamAppId=[1-9][0-9]*' /proc/[0-9]*/environ 2>/dev/null \
        | tr '\0' '\n' | cut -d= -f2 | head -1 || true)

      if [ -z "$appid" ]; then
        echo "gsr-sort-clip: no Steam game running, leaving clip in place" >&2
        exit 0
      fi

      name=$(sed -n 's|^[[:space:]]*"name"[[:space:]]*"\(.*\)"|\1|p' \
        "$HOME/.steam/root/steamapps/appmanifest_$appid.acf" 2>/dev/null | head -1 || true)
      label=$(printf '%s' "''${name:-AppID $appid}" | tr '/' '_')

      dir="$(dirname "$file")/$label"
      mkdir -p "$dir"
      mv -- "$file" "$dir/"
      echo "gsr-sort-clip: $label <- $(basename "$file")"
    '';
  };
in {
  services.gpu-screen-recorder = {
    enable = true;
    postRecordSeconds = 10;
    postSaveScript = sortClipScript;
    # Everything but spotify
    audioDevices = ["app-inverse:spotify|default_input"];
  };
}
