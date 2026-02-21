{
  pkgs,
  config,
  ...
}: let
  inherit (pkgs) anyrun;
  c = config.lib.stylix.colors.withHashtag;
in {
  programs.anyrun = {
    enable = true;
    config = {
      x = {fraction = 0.5;};
      y = {fraction = 0.3;};
      width = {fraction = 0.3;};
      hideIcons = false;
      layer = "overlay";
      hidePluginInfo = true;
      closeOnClick = true;
      showResultsImmediately = true;
      maxEntries = 5;
      plugins = [
        "${anyrun}/lib/libapplications.so"
        "${anyrun}/lib/libshell.so"
        "${anyrun}/lib/librink.so"
        "${anyrun}/lib/libwebsearch.so"
      ];
    };

    extraConfigFiles = {
      "applications.ron".text = ''
        Config(
          desktop_actions: false,
          max_entries: 5,
          terminal: Some(("ghostty", "-e {}")),
        )
      '';
      "websearch.ron".text = ''
        Config(
          prefix: "?",
          engines: [Google],
        )
      '';
    };

    extraCss = ''
      window {
        background-color: rgba(0, 0, 0, 0);
      }

      box.main {
        background-color: ${c.base00};
        border: 1px solid ${c.base02};
        border-radius: 14px;
        padding: 0;
        margin: 8px;
        box-shadow: 0 16px 48px rgba(0, 0, 0, 0.55),
                    0 4px 12px rgba(0, 0, 0, 0.3);
        min-width: 640px;
      }

      text {
        padding: 0.8em 1em;
        color: ${c.base05};
        background-color: transparent;
        font-size: 1.2em;
      }

      .matches {
        background-color: transparent;
        border-top: 1px solid ${c.base02};
        padding: 0.4em;
      }

      box.plugin:first-child { margin-top: 0; }
      box.plugin.info { min-width: 0; }
      list.plugin { background-color: transparent; }

      .match {
        background: transparent;
        padding: 0.3em 0.6em;
        border-radius: 8px;
        transition: background-color 0.12s ease;
      }

      .match:selected {
        background-color: ${c.base02};
      }

      .match image {
        margin-right: 0.8em;
        min-width: 2.2em;
        min-height: 2.2em;
        -gtk-icon-size: 2.2em;
      }

      label.match.title {
        color: ${c.base05};
      }

      .match:selected label.match.title {
        color: ${c.base06};
      }

      label.match.description {
        font-size: 0.8em;
        color: ${c.base04};
      }

      .match:selected label.match.description {
        color: ${c.base05};
      }

      label.plugin.info {
        font-size: 0.8em;
        color: ${c.base03};
      }
    '';
  };

  systemd.user.services.anyrun-daemon = {
    Unit = {
      Description = "Anyrun launcher daemon";
      After = ["graphical-session.target" "hyprland-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.anyrun}/bin/anyrun daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  wayland.windowManager.hyprland.settings = {
    bind = ["SUPER,space,exec,anyrun"];
  };
}
