# GPU Screen Recorder replay buffer.
#
# Importing hosts must set `services.gpu-screen-recorder.display`, and usually
# `matchMonitorName`. HDR monitors record direct (KMS) with an HDR codec; the
# module converts those clips to SDR (see its `hdrClips`).
{
  pkgs,
  lib,
  ...
}: let
  # GSR matches pipewire node.name exactly; VLC's embeds its version, minus nixpkgs' -N suffix.
  vlcAudioName = "VLC media player (LibVLC ${lib.head (lib.splitString "-" pkgs.vlc.version)})";

  # Sorts each saved clip into <Steam game name>/, or Minecraft/<instance>/, and
  # prints its final path for the module's post-save steps.
  clipSavedScript = pkgs.writeShellApplication {
    name = "gsr-clip-saved";
    runtimeInputs = with pkgs; [coreutils gnugrep gnused];
    text = ''
      file="''${1:?usage: gsr-clip-saved <filepath> [type]}"
      [ -f "$file" ] || exit 0

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
        echo "gsr-clip-saved: no game running, leaving clip in place" >&2
        echo "$file"
        exit 0
      fi

      dir="$(dirname "$file")/$subdir"
      mkdir -p "$dir"
      mv -- "$file" "$dir/"
      echo "gsr-clip-saved: $subdir <- $(basename "$file")" >&2
      echo "$dir/$(basename "$file")"
    '';
  };
in {
  services.gpu-screen-recorder = {
    enable = true;
    postRecordSeconds = 10;
    postSaveScript = clipSavedScript;
    # Keep as one -a: separate flags make separate tracks, and players play only the first.
    audioDevices = ["app-inverse:spotify|app-inverse:${vlcAudioName}|default_input"];
  };
}
