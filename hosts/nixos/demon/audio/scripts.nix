{pkgs, ...}: let
  # Device identifiers - update these if your hardware changes
  headsetDevice = "alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo";

  # Discord mute/unmute sound effects (fetched from MyInstants)
  muteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discordmute_IZNcLx2.mp3";
    sha256 = "4c73fcd425d8dddfef0d2ad970f2fd414be7eb1d190f49b7098e8d638f438039";
  };
  unmuteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discord-unmute-sound.mp3";
    sha256 = "b7f6ec23ccabb8183ee2e8073fd4213cffa2241a312bdb1105ee9f0b2cca5576";
  };
in {
  # ============================================================================
  # Audio Control Scripts
  # ============================================================================
  # Provides commands for controlling microphone mute state and soundboard.
  # - mic-mute: Mute the microphone with sound feedback
  # - mic-unmute: Unmute the microphone with sound feedback
  # - mic-toggle: Toggle mute state with appropriate sound feedback
  # - soundboard: Play audio files through the soundboard sink
  # ============================================================================

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "mic-mute" ''
      # Get main_input ID dynamically
      ID=$(${pkgs.wireplumber}/bin/wpctl status | ${pkgs.gnugrep}/bin/grep -E "main_input.*\[Audio/Source\]" | ${pkgs.gawk}/bin/awk '{print $3}' | ${pkgs.gnused}/bin/sed 's/\.//')
      if [ -z "$ID" ]; then
        echo "Error: Could not find main_input audio source"
        exit 1
      fi
      ${pkgs.wireplumber}/bin/wpctl set-mute "$ID" 1
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 --target=${headsetDevice} ${muteSound} &
    '')
    (pkgs.writeShellScriptBin "mic-unmute" ''
      # Get main_input ID dynamically
      ID=$(${pkgs.wireplumber}/bin/wpctl status | ${pkgs.gnugrep}/bin/grep -E "main_input.*\[Audio/Source\]" | ${pkgs.gawk}/bin/awk '{print $3}' | ${pkgs.gnused}/bin/sed 's/\.//')
      if [ -z "$ID" ]; then
        echo "Error: Could not find main_input audio source"
        exit 1
      fi
      ${pkgs.wireplumber}/bin/wpctl set-mute "$ID" 0
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 --target=${headsetDevice} ${unmuteSound} &
    '')
    (pkgs.writeShellScriptBin "mic-toggle" ''
      # Get main_input ID dynamically
      ID=$(${pkgs.wireplumber}/bin/wpctl status | ${pkgs.gnugrep}/bin/grep -E "main_input.*\[Audio/Source\]" | ${pkgs.gawk}/bin/awk '{print $3}' | ${pkgs.gnused}/bin/sed 's/\.//')
      if [ -z "$ID" ]; then
        echo "Error: Could not find main_input audio source"
        exit 1
      fi

      # Get current mute state
      current_state=$(${pkgs.wireplumber}/bin/wpctl get-volume "$ID" | ${pkgs.gnugrep}/bin/grep -o 'MUTED' || echo "")

      # Toggle the mute state
      ${pkgs.wireplumber}/bin/wpctl set-mute "$ID" toggle

      # Play appropriate sound based on new state (opposite of current)
      if [ -z "$current_state" ]; then
        # Was unmuted, now muted
        ${pkgs.pipewire}/bin/pw-play --volume=0.2 --target=${headsetDevice} ${muteSound} &
      else
        # Was muted, now unmuted
        ${pkgs.pipewire}/bin/pw-play --volume=0.2 --target=${headsetDevice} ${unmuteSound} &
      fi
    '')
    (pkgs.writeShellScriptBin "soundboard" ''
      # Play audio files to the soundboard sink
      # Usage: soundboard file.mp3 [additional mpv options]
      # Default 45% volume, can be overridden with: soundboard file.mp3 --volume=80
      ${pkgs.mpv}/bin/mpv --no-video --audio-device=pipewire/soundboard_sink --volume=45 "$@"
    '')
  ];
}
