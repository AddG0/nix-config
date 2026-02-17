{
  pkgs,
  config,
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
  mic-toggle = pkgs.writeShellScriptBin "niri-mic-toggle" ''
    MUTED=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | ${pkgs.gnugrep}/bin/grep -o 'MUTED' || echo "")
    noctalia-shell ipc call volume muteInput
    if [ -z "$MUTED" ]; then
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 ${muteSound} &
    else
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 ${unmuteSound} &
    fi
  '';
in {
  programs.niri.settings.binds = {
    # Terminal
    "Mod+Return".action.spawn = "ghostty";

    # App launcher (Noctalia)
    "Mod+D".action.spawn = ["noctalia-shell" "ipc" "call" "launcher" "toggle"];

    # Close window
    "Mod+Q".action.close-window = {};

    # Navigation
    "Mod+Left".action.focus-column-left = {};
    "Mod+Right".action.focus-column-right = {};
    "Mod+Up".action.focus-window-up = {};
    "Mod+Down".action.focus-window-down = {};
    "Mod+H".action.focus-column-left = {};
    "Mod+L".action.focus-column-right = {};
    "Mod+K".action.focus-window-up = {};
    "Mod+J".action.focus-window-down = {};

    # Move windows
    "Mod+Shift+Left".action.move-column-left = {};
    "Mod+Shift+Right".action.move-column-right = {};
    "Mod+Shift+Up".action.move-window-up = {};
    "Mod+Shift+Down".action.move-window-down = {};
    "Mod+Shift+H".action.move-column-left = {};
    "Mod+Shift+L".action.move-column-right = {};
    "Mod+Shift+K".action.move-window-up = {};
    "Mod+Shift+J".action.move-window-down = {};

    # Sizing
    "Mod+F".action.maximize-column = {};
    "Mod+Shift+F".action.fullscreen-window = {};
    "Mod+R".action.switch-preset-column-width = {};
    "Mod+Minus".action.set-column-width = "-10%";
    "Mod+Equal".action.set-column-width = "+10%";

    # Overview
    "Mod+O".action.toggle-overview = {};

    # Workspaces
    "Mod+1".action.focus-workspace = 1;
    "Mod+2".action.focus-workspace = 2;
    "Mod+3".action.focus-workspace = 3;
    "Mod+4".action.focus-workspace = 4;
    "Mod+5".action.focus-workspace = 5;
    "Mod+Shift+1".action.move-column-to-workspace = 1;
    "Mod+Shift+2".action.move-column-to-workspace = 2;
    "Mod+Shift+3".action.move-column-to-workspace = 3;
    "Mod+Shift+4".action.move-column-to-workspace = 4;
    "Mod+Shift+5".action.move-column-to-workspace = 5;

    # Scroll through workspaces
    "Mod+Page_Down".action.focus-workspace-down = {};
    "Mod+Page_Up".action.focus-workspace-up = {};

    # Move column to monitor
    "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = {};
    "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = {};

    # Screenshot
    "Print".action.screenshot = {};
    "Shift+Print".action.screenshot-window = {};

    # Lock & power
    "Mod+Escape".action.spawn = ["${pkgs.swaylock}/bin/swaylock"];

    # Session
    "Mod+Shift+E".action.quit = {};

    # Audio (via Noctalia OSD)
    "XF86AudioRaiseVolume".action.spawn = ["noctalia-shell" "ipc" "call" "volume" "increase"];
    "XF86AudioLowerVolume".action.spawn = ["noctalia-shell" "ipc" "call" "volume" "decrease"];
    "XF86AudioMute".action.spawn = ["noctalia-shell" "ipc" "call" "volume" "muteOutput"];

    # Mic (via Noctalia OSD)
    "XF86AudioMicMute".action.spawn = ["noctalia-shell" "ipc" "call" "volume" "muteInput"];

    # Media (via Noctalia)
    "XF86AudioPlay".action.spawn = ["noctalia-shell" "ipc" "call" "media" "playPause"];
    "XF86AudioPause".action.spawn = ["noctalia-shell" "ipc" "call" "media" "playPause"];
    "XF86AudioNext".action.spawn = ["noctalia-shell" "ipc" "call" "media" "next"];
    "XF86AudioPrev".action.spawn = ["noctalia-shell" "ipc" "call" "media" "previous"];
    "XF86AudioStop".action.spawn = ["noctalia-shell" "ipc" "call" "media" "stop"];

    # Brightness (via Noctalia OSD)
    "XF86MonBrightnessUp".action.spawn = ["noctalia-shell" "ipc" "call" "brightness" "increase"];
    "XF86MonBrightnessDown".action.spawn = ["noctalia-shell" "ipc" "call" "brightness" "decrease"];

    # Mic toggle (Discord mute/unmute sounds + noctalia OSD)
    "Mod+M".action.spawn = "${mic-toggle}/bin/niri-mic-toggle";

    # GPU Screen Recorder replay
    "Mod+X".action.spawn = "save-gsr-replay";
    "Mod+F10".action.spawn = ["systemctl" "--user" "stop" "gpu-screen-recorder-replay.service"];
    "Mod+F11".action.spawn = ["systemctl" "--user" "start" "gpu-screen-recorder-replay.service"];

    # Consume (eat the key without action)
    "Mod+T".action.consume-or-expel-window-left = {};
    "Mod+Shift+T".action.consume-or-expel-window-right = {};

    # Screen annotation (wayscriber)
    "Mod+A".action.spawn = ["${pkgs.procps}/bin/pkill" "-SIGUSR1" "wayscriber"];
  };
}
