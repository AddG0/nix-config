{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  sans = config.stylix.fonts.sansSerif.name;
  mono = config.stylix.fonts.monospace.name;
  power-menu = pkgs.writeShellScript "power-menu" ''
    choice=$(printf "  Lock\n  Suspend\n  Reboot\n  Shutdown\n  Log Out" | ${pkgs.wofi}/bin/wofi --dmenu --prompt "Power" --width 250 --height 230 --cache-file /dev/null)
    case "$choice" in
      *Lock)     hyprlock ;;
      *Suspend)  systemctl suspend ;;
      *Reboot)   systemctl reboot ;;
      *Shutdown) systemctl poweroff ;;
      *Log\ Out) hyprctl dispatch exit ;;
    esac
  '';
in {
  stylix.targets.waybar.addCss = false;
  stylix.targets.waybar.background = null;

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 44;
        margin-top = 10;
        margin-left = 10;
        margin-right = 10;

        modules-left = ["custom/shq" "hyprland/workspaces" "hyprland/window"];
        modules-center = ["clock"];
        modules-right = [
          "mpris"
          "privacy"
          "cpu"
          "memory"
          "temperature"
          "bluetooth"
          "network"
          "wireplumber"
          "idle_inhibitor"
          "tray"
          "custom/power"
        ];

        "custom/shq" = {
          format = "✦";
          tooltip = false;
        };

        # ── Navigation ──
        "hyprland/workspaces" = {
          format = "{id}";
          on-click = "activate";
          sort-by-number = true;
          all-outputs = false;
        };
        "hyprland/window" = {
          format = "{}";
          max-length = 40;
          rewrite = {
            "(.*) — Mozilla Firefox" = " $1";
            "(.*) — Zen Browser" = " $1";
            "(.*) - Visual Studio Code" = " $1";
          };
          separate-outputs = true;
        };

        # ── Clock ──
        clock = {
          format = "{:%a %b %d  ·  %I:%M %p}";
          format-alt = "{:%Y-%m-%d  ·  %H:%M:%S}";
          tooltip-format = "<tt><span font_family='${mono}' size='small'>{calendar}</span></tt>";
          calendar = {
            mode = "month";
            weeks-pos = "left";
            on-scroll = 1;
            format = {
              months = "<span color='${c.base0D}'><b>{}</b></span>";
              weeks = "<span color='${c.base03}'><b>W{}</b></span>";
              weekdays = "<span color='${c.base0B}'><b>{}</b></span>";
              today = "<span color='${c.base00}' bgcolor='${c.base0D}'><b> {} </b></span>";
              days = "<span color='${c.base05}'>{}</span>";
            };
          };
        };

        # ── Media ──
        mpris = {
          format = "{player_icon} {title} – {artist}";
          format-paused = "{player_icon} {title}";
          max-length = 35;
          player-icons = {
            default = "▶";
            spotify = "";
            firefox = "";
          };
          status-icons.paused = "";
          tooltip = false;
        };

        # ── System Health (hidden until threshold) ──
        cpu = {
          format = "";
          format-above-threshold = " {usage}%";
          threshold = 60;
          interval = 5;
          tooltip-format = "{avg_frequency} GHz · {usage}% across {num_cores} cores";
        };
        memory = {
          format = "";
          format-above-threshold = " {percentage}%";
          threshold = 70;
          interval = 5;
          tooltip-format = "{used:0.1f} / {total:0.1f} GiB";
        };
        temperature = {
          hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
          input-filename = "temp1_input";
          format = "";
          format-critical = " {temperatureC}°";
          critical-threshold = 80;
          interval = 5;
          tooltip-format = "{temperatureC}°C";
        };

        # ── Connectivity ──
        privacy = {
          icon-spacing = 4;
          icon-size = 16;
          transition-duration = 250;
          modules = [
            {
              type = "screenshare";
              tooltip = true;
              tooltip-icon-size = 20;
            }
            {
              type = "audio-in";
              tooltip = true;
              tooltip-icon-size = 20;
            }
          ];
        };
        bluetooth = {
          format = "󰂯";
          format-connected = "󰂱 {device_alias}";
          format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
          format-disabled = "󰂲";
          format-off = "󰂲";
          max-length = 30;
          on-click = "${pkgs.blueman}/bin/blueman-manager";
          tooltip-format = "{controller_alias}\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\n\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          tooltip-format-enumerate-connected-battery = "{device_alias}  {device_battery_percentage}%";
        };
        network = {
          format-wifi = "";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}";
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ifname}: {ipaddr}/{cidr}";
          on-click = "nm-connection-editor";
        };

        # ── Controls ──
        wireplumber = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 mute";
          format-icons = ["" "" ""];
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
          on-scroll-up = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-";
          tooltip = false;
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰛊";
          };
          tooltip-format-activated = "Screen lock inhibited";
          tooltip-format-deactivated = "Screen lock active";
        };
        tray = {spacing = 8;};
        "custom/power" = {
          format = "⏻";
          tooltip = false;
          on-click = "${power-menu}";
        };
      }
    ];

    style = let
      glass = "alpha(${c.base00}, 0.65)";
      border = "alpha(${c.base02}, 0.35)";
      fg = c.base04; # muted foreground — monochrome default
      dim = c.base03; # disabled / inactive
    in ''
      /* ---- Reset ---- */
      * {
        font-family: "${sans}", sans-serif;
        font-size: 13px;
        font-weight: 500;
        min-height: 0;
        padding: 0;
        margin: 0;
        background: none;
        border: none;
      }

      window#waybar {
        background: rgba(0, 0, 0, 0);
        color: ${fg};
      }

      /* ---- Capsule islands ---- */
      .modules-left,
      .modules-center,
      .modules-right {
        background: ${glass};
        border: 1px solid ${border};
        border-radius: 14px;
        margin: 6px 4px;
      }

      /* ---- Left ---- */
      #custom-shq {
        font-size: 15px;
        color: ${c.base0D};
        padding: 4px 12px 4px 16px;
      }

      #workspaces {
        padding: 0 4px;
      }
      #workspaces button {
        font-family: "${mono}", monospace;
        font-size: 13px;
        font-weight: 500;
        padding: 4px 10px;
        margin: 4px 2px;
        color: ${dim};
        background: transparent;
        border: none;
        border-radius: 8px;
        text-decoration: none;
        box-shadow: none;
        transition: all 0.15s ease;
      }
      #workspaces button.active {
        font-weight: 600;
        color: ${c.base07};
        background: alpha(${c.base0D}, 0.18);
      }
      #workspaces button.urgent { color: ${c.base08}; }
      #workspaces button:hover {
        color: ${c.base05};
        background: alpha(${c.base05}, 0.06);
      }

      #window {
        font-size: 13px;
        color: ${dim};
        padding: 4px 16px;
      }
      window#waybar.empty #window { padding: 0; margin: 0; }

      /* ---- Center ---- */
      #clock {
        font-size: 13px;
        font-weight: 600;
        font-feature-settings: "tnum";
        color: ${c.base05};
        padding: 4px 20px;
        letter-spacing: 0.5px;
      }

      /* ---- Right modules (shared base) ---- */
      #mpris, #cpu, #memory, #temperature,
      #privacy, #bluetooth, #network,
      #wireplumber, #idle_inhibitor, #tray, #custom-power {
        font-size: 13px;
        padding: 4px 12px;
      }

      /* ── Media ── */
      #mpris {
        padding-left: 16px;
        color: ${c.base0B};
      }
      #mpris.paused { color: ${dim}; }

      /* ── System health ── */
      #cpu { color: ${c.base0E}; }
      #memory { color: ${c.base0C}; }
      #temperature { color: ${c.base09}; }
      #temperature.critical { color: ${c.base08}; }

      /* ── Privacy ── */
      #privacy { color: ${c.base08}; }

      /* ── Connectivity ── */
      #bluetooth { color: ${c.base0D}; }
      #bluetooth.disabled, #bluetooth.off { color: ${dim}; }
      #network { color: ${c.base0B}; }
      #network.disconnected { color: ${c.base08}; }

      /* ── Controls ── */
      #wireplumber { color: ${c.base0A}; }
      #wireplumber.muted { color: ${dim}; }
      #idle_inhibitor.activated { color: ${c.base0A}; }
      #idle_inhibitor.deactivated { color: ${dim}; }

      #custom-power {
        padding-right: 16px;
        color: ${c.base05};
      }
      #custom-power:hover { color: ${c.base08}; }

      #tray > .passive { -gtk-icon-effect: dim; }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }

      /* ---- Tooltips (glass) ---- */
      tooltip {
        background: ${glass};
        border: 1px solid ${border};
        border-radius: 12px;
        padding: 8px 12px;
        color: ${c.base05};
      }
      tooltip label {
        font-size: 13px;
        color: ${c.base05};
      }
    '';
  };

  # SwayOSD — visual overlay for volume/brightness changes
  services.swayosd = {
    enable = true;
    topMargin = 0.9; # near bottom of screen
  };

  # Keybinds
  wayland.windowManager.hyprland.settings = {
    exec-once = ["waybar" "${pkgs.blueman}/bin/blueman-applet"];
    layerrule = [
      "blur on, match:namespace gtk-layer-shell"
      "ignore_alpha 0.3, match:namespace gtk-layer-shell"
    ];
    binde = [
      ",XF86AudioRaiseVolume,exec,swayosd-client --output-volume raise"
      ",XF86AudioLowerVolume,exec,swayosd-client --output-volume lower"
      ",XF86MonBrightnessUp,exec,swayosd-client --brightness raise"
      ",XF86MonBrightnessDown,exec,swayosd-client --brightness lower"
    ];
    bindl = [
      ",XF86AudioMute,exec,swayosd-client --output-volume mute-toggle"
      ",XF86AudioMicMute,exec,swayosd-client --input-volume mute-toggle"
    ];
  };

  programs.hyprlock.enable = true;
}
