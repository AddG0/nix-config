{
  pkgs,
  ...
}: {
  # Plasma Monitor Configuration:
  # - Use `kscreen-doctor -o` to list monitors
  # - Set primary monitor: `kscreen-doctor output.3.primary` (replace 3 with output number)

  programs.plasma = {
    enable = true;

    # Global fonts
    fonts = {
      general = {
        family = "Segoe UI Variable";
        pointSize = 10;
      };
      fixedWidth = {
        family = "JetBrains Mono";
        pointSize = 10;
      };
      small = {
        family = "Segoe UI Variable";
        pointSize = 8;
      };
      toolbar = {
        family = "Segoe UI Variable";
        pointSize = 10;
      };
      menu = {
        family = "Segoe UI Variable";
        pointSize = 10;
      };
      windowTitle = {
        family = "Segoe UI Variable";
        pointSize = 10;
        weight = "demiBold";
      };
    };

    # Workspace configuration
    workspace = {
      # General appearance and behavior
      clickItemTo = "select";
      lookAndFeel = "org.kde.breezedark.desktop";
      wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Patak/contents/images/5120x2880.png";

      # Styling configuration
      styling = {
        # Icon theme
        icons.theme = "papirus-dark";

        # Cursor theme
        cursors = {
          theme = "vimix";
          variant = "dark";
          size = 24;
        };

        # WhiteSur theme
        # themes.whitesur = {
        #   enable = true;
        #   variant = "dark";
        #   windowDecoration = "sharp";
        # };
      };
    };

    # Custom keyboard shortcuts
    hotkeys.commands."launch-ghostty" = {
      name = "Launch Ghostty";
      key = "Meta+Alt+K";
      command = "ghostty";
    };

    hotkeys.commands."save-replay" = {
      name = "Save Replay (Last 60s)";
      key = "Meta+X";
      command = "save-gsr-replay";
    };

    hotkeys.commands."stop-replay-buffer" = {
      name = "Stop GPU Screen Recorder Replay Buffer";
      key = "Meta+F10";
      command = "systemctl --user stop gpu-screen-recorder-replay.service";
    };

    hotkeys.commands."start-replay-buffer" = {
      name = "Start GPU Screen Recorder Replay Buffer";
      key = "Meta+F11";
      command = "systemctl --user start gpu-screen-recorder-replay.service";
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
              launchers = [
                "applications:com.mitchellh.ghostty.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:google-chrome.desktop"
                "applications:discord.desktop"
                "applications:spotify.desktop"
                "applications:steam.desktop"
                "applications:cursor.desktop"
              ];
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
      {
        location = "top";
        height = 26;
        widgets = [
          {
            applicationTitleBar = {
              behavior = {
                activeTaskSource = "activeTask";
              };
              layout = {
                elements = ["windowTitle"];
                horizontalAlignment = "left";
                showDisabledElements = "deactivated";
                verticalAlignment = "center";
              };
              overrideForMaximized.enable = false;
              titleReplacements = [
                {
                  type = "regexp";
                  originalTitle = "^Brave Web Browser$";
                  newTitle = "Brave";
                }
                {
                  type = "regexp";
                  originalTitle = ''\\bDolphin\\b'';
                  newTitle = "File manager";
                }
              ];
              windowTitle = {
                font = {
                  bold = false;
                  fit = "fixedSize";
                  size = 12;
                };
                hideEmptyTitle = true;
                margins = {
                  bottom = 0;
                  left = 10;
                  right = 5;
                  top = 0;
                };
                source = "appName";
              };
            };
          }
          "org.kde.plasma.appmenu"
          "org.kde.plasma.panelspacer"
          {
            # Adding configuration to the widgets can also for example be used to
            # pin apps to the task-manager, which this example illustrates by
            # pinning dolphin and konsole to the task-manager by default with widget-specific options.

            plasmusicToolbar = {
              panelIcon = {
                albumCover = {
                  useAsIcon = false;
                  radius = 8;
                };
                icon = "view-media-track";
              };
              playbackSource = "auto";
              musicControls.showPlaybackControls = true;
              songText = {
                displayInSeparateLines = false;
                maximumWidth = 640;
                scrolling = {
                  behavior = "alwaysScroll";
                  speed = 3;
                };
              };
            };
          }
          "org.kde.plasma.panelspacer"
        ];
        hiding = "autohide";
      }
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
      mice = [
        {
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
      klaunchrc.FeedbackStyle = {
        BusyCursor = false;
        TaskbarButton = false;
      };
    };
  };
}
