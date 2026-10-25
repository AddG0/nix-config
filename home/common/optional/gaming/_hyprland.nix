# How Hyprland runs games: window rules, scanout and colour management, and SDR game mode.
{
  config,
  pkgs,
  lib,
  ...
}: let
  hdrMonitors = lib.filter (m: m.enabled && m.hdr) config.display.monitors;
  sdrGameMode = import ./_sdr-game-mode.nix {
    inherit lib pkgs hdrMonitors;
    hyprland = config.wayland.windowManager.hyprland.package;
  };
in
  lib.mkIf config.wayland.windowManager.hyprland.enable {
    wayland.windowManager.hyprland.settings.bind = lib.optional (hdrMonitors != []) "SUPER ALT,b,exec,${lib.getExe sdrGameMode.toggle}";

    systemd.user.services.sdr-game-mode = lib.mkIf (hdrMonitors != []) {
      Unit = {
        Description = "Switch an HDR monitor to SDR while a fullscreen SDR game is on it";
        After = ["graphical-session.target"];
        PartOf = [config.lib.hyprland.sessionUnit];
      };
      Service = {
        ExecStart = lib.getExe sdrGameMode.switch;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [config.lib.hyprland.sessionUnit];
    };

    # Forza Horizon's XWayland fullscreen-on-map path crashes Hyprland 0.54.3
    # inside CCompositor::setWindowFullscreenInternal (null deref on the
    # surface-recycling that happens during X11 Activate). Suppress the
    # fullscreen request — the game still renders fine windowed-borderless.
    # mkBefore so `tag +game` sorts ahead of the tag:game consumers in other
    # modules (e.g. the opacity rule in visuals) — Hyprland applies rules in order.
    wayland.windowManager.hyprland.settings.windowrule = lib.mkMerge [
      (lib.mkBefore ([
          "suppress_event fullscreen, match:title ^(Forza Horizon \\d+)$"
          "suppress_event fullscreen, match:class ^(steam_app_2483190)$"
          # Scrap Mechanic maps its X11 window as a dialog, so Hyprland auto-floats it tiny.
          "float off, match:class ^(steam_app_387990)$"
          # gamescope's render loop runs off Wayland frame callbacks, which Hyprland
          # stops sending to windows on an inactive workspace — so the game freezes on
          # return until a resize kicks it.
          "render_unfocused on, match:class ^(gamescope)$"
        ]
        ++ map (class: "tag +game, match:class ${class}") config.gaming.windowClasses
        ++ [
          # render.direct_scanout = 2 only scans out windows of content type game.
          # Not gamescope: Hyprland scanning out its buffer directly shows garbage.
          "content game, match:tag game, match:class negative:^(gamescope)$"
        ]))
      # SDR game mode leaves monitors in HDR for windows with this tag.
      (lib.mapAttrsToList (id: _: "tag +keep-hdr, match:class ^(steam_app_${id})$") (lib.filterAttrs (_: app: app.keepHdr) (config.programs.steam.config.apps or {})))
    ];

    wayland.windowManager.hyprland.settings.render = {
      direct_scanout = 2;
      # Default 3 ignores CM for scanout, so SDR games on an HDR output go oversaturated.
      non_shader_cm = 2;
      # Otherwise mode 2 gives non-"none" fullscreen windows an identity CTM and skips shader CM, oversaturating SDR games.
      non_shader_cm_interop = 1;
      # Auto HDR drops the HDR metadata for SDR fullscreen windows but keeps PQ-encoding them, washing them out.
      cm_auto_hdr = 0;
    };
  }
