{pkgs, ...}: let
  # Device identifiers - update these if your hardware changes
  micDevice = "alsa_input.usb-Focusrite_Scarlett_Solo_4th_Gen_S1YE3VE3790E29-00.HiFi__Mic2__source";
  headsetDevice = "alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo";

  # Alert sound for talking while muted (uses freedesktop sound theme)
  mutedTalkingSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/bell.oga";

  # Muted-talking monitor script
  mutedTalkingMonitor = pkgs.writeShellScriptBin "muted-talking-monitor" ''
    # Monitors microphone levels while muted and plays alert sound if talking
    # Configuration
    DB_THRESHOLD=-20         # dB threshold (e.g., -65 = very quiet, -40 = moderate, -20 = loud)
    COOLDOWN_SECONDS=3       # Seconds to wait between alerts to avoid spam
    SAMPLE_DURATION=0.3      # How long to sample audio (seconds)

    last_alert=0

    while true; do
      # Get main_input ID
      ID=$(${pkgs.wireplumber}/bin/wpctl status | ${pkgs.gnugrep}/bin/grep -E "main_input.*\[Audio/Source\]" | ${pkgs.gawk}/bin/awk '{print $3}' | ${pkgs.gnused}/bin/sed 's/\.//')

      if [ -n "$ID" ]; then
        # Check if muted
        mute_state=$(${pkgs.wireplumber}/bin/wpctl get-volume "$ID" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -o 'MUTED' || echo "")

        if [ -n "$mute_state" ]; then
          # We're muted - sample audio from the raw mic (before mute) and get max dB level
          max_db=$(${pkgs.coreutils}/bin/timeout ''${SAMPLE_DURATION}s ${pkgs.pipewire}/bin/pw-record --target="${micDevice}" --format=f32 --rate=48000 --channels=1 - 2>/dev/null | \
            ${pkgs.sox}/bin/sox -t raw -r 48000 -c 1 -e floating-point -b 32 - -n stat 2>&1 | \
            ${pkgs.gnugrep}/bin/grep "Maximum amplitude" | ${pkgs.gawk}/bin/awk '{print $3}')

          if [ -n "$max_db" ] && [ "$max_db" != "0.000000" ]; then
            # Convert amplitude to dB: 20 * log10(amplitude)
            db_level=$(echo "20 * l($max_db) / l(10)" | ${pkgs.bc}/bin/bc -l 2>/dev/null)

            if [ -n "$db_level" ]; then
              # Check if above threshold
              above_threshold=$(echo "$db_level > $DB_THRESHOLD" | ${pkgs.bc}/bin/bc -l 2>/dev/null || echo "0")

              if [ "$above_threshold" = "1" ]; then
                current_time=$(${pkgs.coreutils}/bin/date +%s)
                time_since_alert=$((current_time - last_alert))

                if [ $time_since_alert -ge $COOLDOWN_SECONDS ]; then
                  # Play alert sound
                  ${pkgs.pipewire}/bin/pw-play --volume=0.3 --target=${headsetDevice} ${mutedTalkingSound} &
                  last_alert=$current_time
                fi
              fi
            fi
          fi
        fi
      fi
    done
  '';
in {
  # ============================================================================
  # Muted-Talking Monitor
  # ============================================================================
  # Alerts you when you try to speak while your microphone is muted.
  # Start manually with: muted-talking-enable
  # Stop with: muted-talking-disable
  # Check status: muted-talking-status
  # ============================================================================

  environment.systemPackages = [
    mutedTalkingMonitor
    (pkgs.writeShellScriptBin "muted-talking-enable" ''
      ${pkgs.systemd}/bin/systemctl --user start muted-talking-monitor
      echo "Muted-talking monitor enabled"
    '')
    (pkgs.writeShellScriptBin "muted-talking-disable" ''
      ${pkgs.systemd}/bin/systemctl --user stop muted-talking-monitor
      echo "Muted-talking monitor disabled"
    '')
    (pkgs.writeShellScriptBin "muted-talking-status" ''
      ${pkgs.systemd}/bin/systemctl --user status muted-talking-monitor
    '')
  ];

  # Muted-talking monitor service
  # Not in wantedBy - must be manually enabled with muted-talking-enable
  systemd.user.services.muted-talking-monitor = {
    description = "Monitor for talking while muted";
    after = ["pipewire.service" "wireplumber.service"];
    wants = ["pipewire.service" "wireplumber.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${mutedTalkingMonitor}/bin/muted-talking-monitor";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
