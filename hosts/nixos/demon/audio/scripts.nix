{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "music-monitor" ''
      # Discord's feed is its own tap off music_source, so muting here never
      # touches it. Mute rather than unlink: the session manager owns this link
      # and would just remake it.
      ID=$(${pkgs.pipewire}/bin/pw-dump \
        | ${pkgs.jq}/bin/jq -r '.[] | select(.info.props."node.name" == "music_monitor") | .id' \
        | ${pkgs.coreutils}/bin/head -1)
      if [ -z "$ID" ]; then
        echo "Error: no music_monitor node — is PipeWire running?" >&2
        exit 1
      fi
      ${pkgs.wireplumber}/bin/wpctl set-mute "$ID" toggle
      if ${pkgs.wireplumber}/bin/wpctl get-volume "$ID" | ${pkgs.gnugrep}/bin/grep -q MUTED; then
        echo "Music monitor: OFF (Discord only)"
      else
        echo "Music monitor: ON (Discord + headphones)"
      fi
    '')
    (pkgs.writeShellScriptBin "soundboard" ''
      # Usage: soundboard file.mp3 [mpv options] — a later --volume wins.
      # What you hear is a second stream, not a soundboard_source→DAC link, which
      # would merge the capture and playback graphs — see virtual-devices.nix.
      ${pkgs.mpv}/bin/mpv --no-video --audio-device=pipewire/soundboard_sink --volume=45 "$@" &
      ${pkgs.mpv}/bin/mpv --no-video --volume=45 "$@" &
      wait
    '')
  ];
}
