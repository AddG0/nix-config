{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  noc = "${config.programs.noctalia-shell.package}/bin/noctalia-shell";
  settingsPath = "$XDG_RUNTIME_DIR/noctalia/settings.json";
  nixSettings = config.xdg.configFile."noctalia/settings.json".source;
  # Noctalia caches weather in ~/.cache/noctalia/location.json
  # If weather is wrong after changing location, delete that file and restart.
  locate-city = pkgs.writeShellScript "noctalia-locate-city" ''
    mkdir -p "$XDG_RUNTIME_DIR/noctalia"
    cp --no-preserve=mode ${nixSettings} ${settingsPath}
    for i in 1 2 3; do
      CITY=$(${pkgs.curl}/bin/curl -sf --max-time 5 "http://ip-api.com/json/?fields=city" | ${pkgs.jq}/bin/jq -r '.city // empty')
      [ -n "$CITY" ] && break
      sleep 2
    done
    if [ -n "$CITY" ]; then
      ${pkgs.jq}/bin/jq --arg city "$CITY" '.location.name = $city' ${settingsPath} > ${settingsPath}.tmp \
        && mv ${settingsPath}.tmp ${settingsPath}
    fi
  '';
  muteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discordmute_IZNcLx2.mp3";
    sha256 = "4c73fcd425d8dddfef0d2ad970f2fd414be7eb1d190f49b7098e8d638f438039";
  };
  unmuteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discord-unmute-sound.mp3";
    sha256 = "b7f6ec23ccabb8183ee2e8073fd4213cffa2241a312bdb1105ee9f0b2cca5576";
  };
  mic-toggle = pkgs.writeShellScriptBin "hypr-mic-toggle" ''
    MUTED=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | ${pkgs.gnugrep}/bin/grep -o 'MUTED' || echo "")
    ${noc} ipc call volume muteInput
    if [ -z "$MUTED" ]; then
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 ${muteSound} &
    else
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 ${unmuteSound} &
    fi
  '';
in {
  imports = [inputs.noctalia.homeModules.default];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;

    settings = {
      settingsVersion = 53;
      bar.position = "top";
      bar.widgets.left = [
        {id = "Launcher";}
        {
          id = "Clock";
          formatHorizontal = "hh:mm AP ddd, MMM dd";
          formatVertical = "hh\nmm AP";
          tooltipFormat = "hh:mm AP ddd, MMM dd";
        }
        {id = "SystemMonitor";}
        {id = "ActiveWindow";}
        {id = "MediaMini";}
      ];
      bar.widgets.right = [
        {id = "Tray";}
        {id = "Microphone";}
        {id = "NotificationHistory";}
        {id = "Volume";}
        {id = "ControlCenter";}
      ];
      notifications.monitors = map (m: m.name) (builtins.filter (m: m.primary) config.monitors);
      location.useFahrenheit = true;
      location.use12hourFormat = true;
      nightLight = {
        enabled = true;
        autoSchedule = false;
        manualSunrise = "06:30";
        manualSunset = "18:00";
        dayTemp = 6000;
        nightTemp = 4500;
      };
      colorSchemes.predefinedScheme = "Catppuccin";
      general.avatarImage = "/var/lib/AccountsService/icons/${config.home.username}";
    };
  };

  # Wait for Hyprland's Wayland socket before starting, otherwise
  # quickshell fails with "Failed to create wl_display" and crash-loops.
  systemd.user.services.noctalia-shell.Unit.After = lib.mkForce ["graphical-session.target" "hyprland-session.target"];
  systemd.user.services.noctalia-shell.Service.ExecStartPre = lib.mkBefore [locate-city];
  systemd.user.services.noctalia-shell.Service.Environment = [
    "NOCTALIA_SETTINGS_FILE=%t/noctalia/settings.json"
  ];

  # Noctalia IPC binds
  wayland.windowManager.hyprland.settings = {
    binde = [
      ",XF86AudioRaiseVolume,exec,${noc} ipc call volume increase"
      ",XF86AudioLowerVolume,exec,${noc} ipc call volume decrease"
      ",XF86MonBrightnessUp,exec,${noc} ipc call brightness increase"
      ",XF86MonBrightnessDown,exec,${noc} ipc call brightness decrease"
    ];
    bindl = [
      ",XF86AudioMute,exec,${noc} ipc call volume muteOutput"
      ",XF86AudioMicMute,exec,${noc} ipc call volume muteInput"
    ];
    bind = [
      "SUPER,m,exec,${mic-toggle}/bin/hypr-mic-toggle"
    ];
  };
}
