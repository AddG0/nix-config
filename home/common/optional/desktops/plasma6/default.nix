{
  config,
  osConfig ? null,
  lib,
  pkgs,
  customPkgs,
  self,
  ...
}: let
  installed = map lib.getName (config.home.packages ++ osConfig.environment.systemPackages or []);
  # [pname desktop-file]; a pin is dropped when no installed package has that pname.
  pins = [
    ["ghostty" "com.mitchellh.ghostty.desktop"]
    ["dolphin" "org.kde.dolphin.desktop"]
    ["zen-beta" "zen-beta.desktop"]
    ["discord" "discord.desktop"]
    ["spotify" "spotify.desktop"]
    ["steam" "steam.desktop"]
    ["vscode" "code.desktop"]
  ];
in {
  assertions = [(lib.hm.assertions.assertPlatform "home.desktops.plasma6" pkgs lib.platforms.linux)];

  imports = [
    self.homeModules.plasma6
    ./stylix.nix
  ];

  # Plasma Monitor Configuration:
  # - Use `kscreen-doctor -o` to list monitors
  # - Set primary monitor: `kscreen-doctor output.3.primary` (replace 3 with output number)

  # Symlink timezone-hover plasmoid to XDG data directory so Plasma can find it
  xdg.dataFile."plasma/plasmoids/com.github.timezonehover".source = "${customPkgs.timezone-hover}/share/plasma/plasmoids/com.github.timezonehover";

  # Its plasma-apply-cursortheme runs plasma-setup-xwayland, which pushes kwinrc's Xwayland scale into any session's Xft.dpi.
  xdg.configFile."autostart/plasma-manager-autostart.desktop".text = lib.mkAfter "OnlyShowIn=KDE;";

  # FLAKE-UPDATE: drop once startkde/plasma-shutdown/shutdown.cpp stops graphical-session.target in a mode other than "fail".
  # A D-Bus-activated portal (Requisite=graphical-session.target) cancels that stop, so UWSM then refuses to start.
  xdg.configFile."plasma-workspace/shutdown/stop-graphical-session.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec ${lib.getExe' pkgs.systemd "systemctl"} --user stop --job-mode=replace-irreversibly --no-block graphical-session.target
    '';
  };

  programs.plasma = {
    enable = true;

    # Workspace configuration
    workspace = {
      # General appearance and behavior
      clickItemTo = "select";

      splashScreen = {
        theme = "Noir-Splash-6";
      };

      # themes.whitesur = {
      #   enable = true;
      #   variant = "dark";
      #   windowDecoration = "sharp";
      # };
    };

    # Custom keyboard shortcuts
    hotkeys.commands."launch-ghostty" = {
      name = "Launch Ghostty";
      key = "Meta+Alt+K";
      command = "ghostty";
    };

    hotkeys.commands."mic-toggle" = {
      name = "Toggle Microphone Mute";
      key = "Meta+M";
      command = "mic-toggle";
    };

    # Panel configuration
    panels = [
      # Windows-like taskbar at the bottom
      {
        location = "bottom";
        screen = "all";
        floating = true;
        opacity = "translucent";
        widgets = [
          {
            kickoff = {
              sortAlphabetically = true;
              icon = "nix-snowflake-white";
            };
          }
          {
            iconTasks = {
              iconsOnly = true;
              launchers = map (p: "applications:${lib.last p}") (lib.filter (p: lib.elem (lib.head p) installed) pins);
              appearance = {
                showTooltips = true;
                highlightWindows = true;
                iconSpacing = "small";
                fill = false;
                rows.multirowView = "lowSpace";
              };
              behavior = {
                grouping.method = "byProgramName";
                grouping.clickAction = "cycle";
                sortingMethod = "manually";
                minimizeActiveTaskOnClick = true;
                middleClickAction = "close";
                wheel.switchBetweenTasks = true;
                showTasks.onlyInCurrentDesktop = true;
                newTasksAppearOn = "right";
              };
            };
          }

          "org.kde.plasma.panelspacer"
          {
            systemTray.items = {
              shown = [
                "com.github.timezonehover"
              ];
              # We explicitly show bluetooth and battery
              # shown = [
              #   "org.kde.plasma.battery"
              #   "org.kde.plasma.bluetooth"
              # ];
              # # And explicitly hide networkmanagement and volume
              # hidden = [
              #   "org.kde.plasma.networkmanagement"
              #   "org.kde.plasma.volume"
              # ];
            };
          }
          {
            digitalClock = {
              time.format = "12h";
              time.showSeconds = "never";
              date.enable = true;
              date.format = "shortDate";
              calendar.firstDayOfWeek = "monday";
              font = {
                family = "Segoe UI Variable";
                size = 13;
                bold = true;
              };
            };
          }
        ];
        # hiding = "autohide";
      }
      # Application name, Global menu and Song information and playback controls at the top
      # {
      #   location = "top";
      #   height = 26;
      #   widgets = [
      #     {
      #       applicationTitleBar = {
      #         behavior = {
      #           activeTaskSource = "activeTask";
      #         };
      #         layout = {
      #           elements = ["windowTitle"];
      #           horizontalAlignment = "left";
      #           showDisabledElements = "deactivated";
      #           verticalAlignment = "center";
      #         };
      #         overrideForMaximized.enable = false;
      #         titleReplacements = [
      #           {
      #             type = "regexp";
      #             originalTitle = "^Brave Web Browser$";
      #             newTitle = "Brave";
      #           }
      #           {
      #             type = "regexp";
      #             originalTitle = ''\\bDolphin\\b'';
      #             newTitle = "File manager";
      #           }
      #         ];
      #         windowTitle = {
      #           font = {
      #             bold = false;
      #             fit = "fixedSize";
      #             size = 12;
      #           };
      #           hideEmptyTitle = true;
      #           margins = {
      #             bottom = 0;
      #             left = 10;
      #             right = 5;
      #             top = 0;
      #           };
      #           source = "appName";
      #         };
      #       };
      #     }
      #     "org.kde.plasma.appmenu"
      #     "org.kde.plasma.panelspacer"
      #     {
      #       # Adding configuration to the widgets can also for example be used to
      #       # pin apps to the task-manager, which this example illustrates by
      #       # pinning dolphin and konsole to the task-manager by default with widget-specific options.

      #       plasmusicToolbar = {
      #         panelIcon = {
      #           albumCover = {
      #             useAsIcon = false;
      #             radius = 8;
      #           };
      #           icon = "view-media-track";
      #         };
      #         playbackSource = "auto";
      #         musicControls.showPlaybackControls = true;
      #         songText = {
      #           displayInSeparateLines = false;
      #           maximumWidth = 640;
      #           scrolling = {
      #             behavior = "alwaysScroll";
      #             speed = 3;
      #           };
      #         };
      #       };
      #     }
      #     "org.kde.plasma.panelspacer"
      #   ];
      #   hiding = "autohide";
      # }
    ];

    # Power management settings
    powerdevil = {
      AC = {
        powerButtonAction = "lockScreen";
        autoSuspend = {
          action = "nothing";
          idleTimeout = null;
        };
        turnOffDisplay = {
          idleTimeout = "never";
          idleTimeoutWhenLocked = null;
        };
        dimDisplay = {
          enable = false;
        };
      };
      battery = {
        powerButtonAction = "sleep";
        autoSuspend = {
          action = "nothing";
          idleTimeout = null;
        };
        turnOffDisplay = {
          idleTimeout = "never";
          idleTimeoutWhenLocked = null;
        };
        dimDisplay = {
          enable = false;
        };
      };
      lowBattery = {
        powerButtonAction = "sleep";
        autoSuspend = {
          action = "nothing";
        };
        turnOffDisplay = {
          idleTimeout = "never";
        };
        dimDisplay = {
          enable = false;
        };
      };
    };

    # Screen locker settings
    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
    };

    # Input device configuration
    input = {
      # Remap Caps Lock to Escape
      keyboard.options = ["caps:escape"];

      mice = [
        {
          # The Razer mice is my shared one
          enable = true;
          name = "Razer Razer Viper Mini Signature Edition";
          vendorId = "1532";
          productId = "009f";
          accelerationProfile = "none";
        }
        {
          enable = true;
          name = "Razer Viper Mini Signature Edition";
          vendorId = "1532";
          productId = "009f";
          accelerationProfile = "none";
        }
      ];
    };

    kwin = {
      edgeBarrier = 0; # Disables the edge-barriers introduced in plasma 6.1
      cornerBarrier = false;
      scripts = {
        geometryChange.enable = true;
        squash.enable = true;
        kzone.enable = true;
      };
      nightLight = {
        enable = true;
        mode = "times";
        temperature = {
          night = 2700;
          day = 4000;
        };
        time = {
          evening = "18:00";
          morning = "08:00";
        };
      };
    };

    # Additional KDE configuration files
    configFile = {
      # Start with empty session (don't restore previous apps)
      ksmserverrc.General.loginMode = "emptySession";

      klaunchrc.FeedbackStyle = {
        BusyCursor = false;
        TaskbarButton = false;
      };
      # Disable focus stealing prevention so opened URLs get focus
      kwinrc.Windows = {
        FocusStealingPreventionLevel = 0; # 0=None, 1=Low, 2=Medium, 3=High, 4=Extreme
      };
      # # KRdp - Plasma native Wayland RDP server (hardware-accelerated via VA-API)
      # krdpserverrc.General = {
      #   Autostart = true;
      #   SystemUserEnabled = true; # login with system (PAM) credentials
      # };

      # Disable KWin shortcuts (~/.config/kglobalshortcutsrc)
      kglobalshortcutsrc.kwin = {
        "KZones: Snap active window" = "none,none,KZones: Snap active window";
        "KZones: Snap all windows" = "none,none,KZones: Snap all windows";
        # Free Ctrl+F9 for gromit-mpx (toggle visibility)
        "Expose" = "none,none,Toggle Present Windows (Current desktop)";
      };
    };
  };
}
