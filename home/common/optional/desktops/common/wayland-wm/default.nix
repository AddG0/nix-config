# Session kit for bare compositors (Hyprland, niri); Plasma brings its own.
{
  config,
  lib,
  pkgs,
  ...
}: let
  target = "bare-compositor-session.target";
in {
  imports = [
    ./crash-capture.nix
    # Writes kdeglobals and dolphinrc read-only, so it would fight Plasma over them.
    ./dolphin.nix
    ./idle-lock
    ./night-light.nix
    ./wallpaper
  ];

  options.desktop.session = {
    dpms = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          off = lib.mkOption {
            type = lib.types.str;
            description = "A single command (run with exec) that powers the monitors off.";
          };
          on = lib.mkOption {
            type = lib.types.str;
            description = "A single command (run with exec) that powers the monitors back on.";
          };
        };
      });
      default = {};
      example = lib.literalExpression ''{ niri = { off = "niri msg action power-off-monitors"; on = "niri msg action power-on-monitors"; }; }'';
      description = "Monitor power commands per compositor, keyed by the name it puts in XDG_CURRENT_DESKTOP.";
    };

    reload.commands = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      example = lib.literalExpression ''
        { wpaperd = "systemctl --user try-restart wpaperd.service"; }
      '';
      description = ''
        Shell commands to run when the compositor's config is reloaded by hand
        (Hyprland: SUPER+SHIFT+R), for services that don't re-read it themselves.
        Keyed by short name; each entry runs as plain shell text, in key order.
      '';
    };

    dpmsCommand = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "`session-dpms off|on`, running the current session's entry in desktop.session.dpms.";
    };
  };

  config = {
    desktop.session.dpmsCommand = import ./_session-dpms.nix {
      inherit lib pkgs;
      commands = config.desktop.session.dpms;
    };

    # Started by each bare compositor's own unit, so a Plasma login never runs these services.
    systemd.user.targets.bare-compositor-session.Unit = {
      Description = "Bare-compositor session: services Hyprland and niri share";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    # Home Manager's Wayland services (hypridle, wpaperd, Noctalia, swayosd…) bind to this.
    wayland.systemd.target = target;

    # For modules that hard-code graphical-session.target and offer no option (walker, elephant).
    lib.waylandWm.startWithSession = {
      Install.WantedBy = lib.mkForce [target];
      Unit.PartOf = lib.mkForce [target];
    };
  };
}
