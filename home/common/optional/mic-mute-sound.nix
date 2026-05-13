#
# Plays a discord-style mute / unmute cue whenever the default audio source's
# mute state changes — regardless of which app, hotkey, or hardware key did
# the muting.
#
# Implementation is a tiny systemd user service that subscribes to PipeWire's
# PulseAudio-compatibility event stream via `pactl subscribe`, re-checks the
# mute state on each source/server event, and plays a sound on transitions.
# A wireplumber Lua hook would feel more "native", but WP 0.5 sandboxes
# os.execute / io away from its Lua runtime — so the only practical way to
# trigger a `pw-play` from a WP-internal event is via this kind of out-of-
# process daemon. This is the canonical pattern used by waybar/polybar
# pulseaudio modules and dotfiles doing the same job.
#
{
  pkgs,
  lib,
  ...
}: let
  muteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discordmute_IZNcLx2.mp3";
    sha256 = "4c73fcd425d8dddfef0d2ad970f2fd414be7eb1d190f49b7098e8d638f438039";
  };
  unmuteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discord-unmute-sound.mp3";
    sha256 = "b7f6ec23ccabb8183ee2e8073fd4213cffa2241a312bdb1105ee9f0b2cca5576";
  };

  daemon = pkgs.writeShellScript "mic-mute-sound-daemon" ''
    set -u
    export PATH=${lib.makeBinPath [pkgs.wireplumber pkgs.pulseaudio pkgs.pipewire pkgs.gnugrep]}:$PATH

    current_state() {
      wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null \
        | grep -q MUTED && echo muted || echo unmuted
    }

    play() {
      # Fire-and-forget so we don't block the event loop on a ~1s cue.
      pw-play --volume=0.2 "$1" >/dev/null 2>&1 &
    }

    # Capture initial state without playing — avoids a chirp on service start.
    prev=$(current_state)

    # `pactl subscribe` emits e.g. "Event 'change' on source #50". We don't
    # care which numeric event fired; we just re-check the default source's
    # state on anything that could have touched it.
    pactl subscribe | while IFS= read -r line; do
      case "$line" in
        *"on source"*|*"on server"*)
          cur=$(current_state)
          if [ "$cur" != "$prev" ]; then
            case "$cur" in
              muted)   play "${muteSound}" ;;
              unmuted) play "${unmuteSound}" ;;
            esac
            prev="$cur"
          fi
          ;;
      esac
    done
  '';
in {
  systemd.user.services.mic-mute-sound = {
    Unit = {
      Description = "Play a sound on default-mic mute/unmute transitions";
      After = ["pipewire.service" "wireplumber.service"];
      Wants = ["pipewire.service" "wireplumber.service"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${daemon}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
