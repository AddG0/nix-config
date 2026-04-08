{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  isLaptop = config.hostSpec.hostType == "laptop";
  settingsPath = "$XDG_RUNTIME_DIR/noctalia/settings.json";
  nixSettings = config.xdg.configFile."noctalia/settings.json".source;
  # Noctalia caches weather in ~/.cache/noctalia/location.json
  # If weather is wrong after changing location, delete that file and restart.
  locate-city = pkgs.writeShellScript "noctalia-locate-city" ''
    mkdir -p "$XDG_RUNTIME_DIR/noctalia"
    HASH_FILE="$XDG_RUNTIME_DIR/noctalia/settings.hash"
    NEW_HASH=$(sha256sum ${nixSettings} | cut -d' ' -f1)
    OLD_HASH=$(cat "$HASH_FILE" 2>/dev/null || true)
    if [ ! -f ${settingsPath} ] || [ "$NEW_HASH" != "$OLD_HASH" ]; then
      cp --no-preserve=mode ${nixSettings} ${settingsPath}
      echo "$NEW_HASH" > "$HASH_FILE"
    fi
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
in {
  imports = [inputs.noctalia.homeModules.default];

  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,escape,exec,noctalia-shell ipc call lockScreen lock"
  ];

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
      bar.widgets.right =
        [
          {id = "Tray";}
          {id = "Microphone";}
          {id = "NotificationHistory";}
          {id = "Volume";}
        ]
        ++ lib.optionals isLaptop [
          {id = "Battery";}
        ]
        ++ [
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
  systemd.user.services.noctalia-shell.Unit.After = lib.mkForce ["graphical-session.target"];
  systemd.user.services.noctalia-shell.Service.ExecStartPre = lib.mkBefore [locate-city];
  systemd.user.services.noctalia-shell.Service.Environment = [
    "NOCTALIA_SETTINGS_FILE=%t/noctalia/settings.json"
  ];
}
