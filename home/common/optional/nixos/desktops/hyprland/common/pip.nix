{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.hyprland.pip;

  # Width/height tokens used in the move expression. When `respectSourceSize`
  # is true we don't enforce a size, so move must reference the live window
  # dimensions (window_w/window_h) — that way placement stays correct for
  # any aspect ratio the browser hands us. Otherwise use the literal sizes
  # to dodge the timing race where `window_w` resolves to the browser's
  # initial PiP request before our `size` rule applies.
  moveWidth =
    if cfg.respectSourceSize
    then "window_w"
    else toString cfg.size.width;
  moveHeight =
    if cfg.respectSourceSize
    then "window_h"
    else toString cfg.size.height;

  # Hyprland `move` expression for the configured corner. Uses
  # monitor_w/monitor_h variables so the rule re-resolves per-monitor.
  moveExpr =
    if cfg.corner == "top-right"
    then "(monitor_w-${moveWidth}-${toString cfg.margin}) ${toString cfg.margin}"
    else if cfg.corner == "top-left"
    then "${toString cfg.margin} ${toString cfg.margin}"
    else if cfg.corner == "bottom-right"
    then "(monitor_w-${moveWidth}-${toString cfg.margin}) (monitor_h-${moveHeight}-${toString cfg.margin})"
    else "${toString cfg.margin} (monitor_h-${moveHeight}-${toString cfg.margin})";

  # Bash expressions computing absolute pixel coords from monitor mx/my/mw/mh.
  # Used by the SUPER-bound toggle, which dispatches `movewindowpixel exact`.
  scriptX =
    if cfg.corner == "top-right" || cfg.corner == "bottom-right"
    then "$((mx+mw-${toString cfg.size.width}-${toString cfg.margin}))"
    else "$((mx+${toString cfg.margin}))";
  scriptY =
    if cfg.corner == "top-right" || cfg.corner == "top-left"
    then "$((my+${toString cfg.margin}))"
    else "$((my+mh-${toString cfg.size.height}-${toString cfg.margin}))";

  # `opacity FOCUSED UNFOCUSED [override]`. `override` bypasses the global
  # inactive_opacity setting — necessary if you want video to stay fully
  # opaque while unfocused.
  overrideKw = lib.optionalString cfg.opacity.override " override";
  opacityRule = "opacity ${toString cfg.opacity.focused}${overrideKw} ${toString cfg.opacity.unfocused}${overrideKw}";

  matchTitle = "match:title ${cfg.titleRegex}";

  pip-toggle = pkgs.writeShellScriptBin "hypr-pip-toggle" ''
    set -eu
    PATH="${pkgs.hyprland}/bin:${pkgs.jq}/bin:$PATH"

    dir="''${XDG_RUNTIME_DIR:-/tmp}/hypr-pip"
    mkdir -p "$dir"

    read -r addr fl pin fs x y w h mon < <(
      hyprctl activewindow -j \
        | jq -r '[.address,.floating,.pinned,.fullscreen,.at[0],.at[1],.size[0],.size[1],.monitor]|@tsv'
    )
    case "$addr" in ""|null|0x0) exit 0 ;; esac
    f="$dir/$addr"

    if [ -e "$f" ]; then
      read -r O_fl O_pin O_x O_y O_w O_h < "$f"
      b=""
      [ "$pin" != "$O_pin" ] && b+="dispatch pin address:$addr"
      [ "$fl"  != "$O_fl"  ] && b+="''${b:+ ; }dispatch togglefloating address:$addr"
      [ "$O_fl" = true ] && b+="''${b:+ ; }dispatch resizewindowpixel exact $O_w $O_h,address:$addr ; dispatch movewindowpixel exact $O_x $O_y,address:$addr"
      [ -n "$b" ] && hyprctl --batch "$b"
      rm -f "$f"
    else
      # Fullscreen windows silently reject pin/float/resize — exit first.
      [ "$fs" != 0 ] && hyprctl dispatch fullscreenstate 0 -1
      read -r mx my mw mh < <(
        hyprctl monitors -j | jq -r --argjson i "$mon" '.[]|select(.id==$i)|[.x,.y,.width,.height]|@tsv'
      )
      printf '%s %s %s %s %s %s\n' "$fl" "$pin" "$x" "$y" "$w" "$h" > "$f"
      b=""
      [ "$fl"  != true ] && b+="dispatch togglefloating address:$addr ; "
      ${lib.optionalString cfg.pinned ''[ "$pin" != true ] && b+="dispatch pin address:$addr ; "''}
      b+="dispatch resizewindowpixel exact ${toString cfg.size.width} ${toString cfg.size.height},address:$addr"
      b+=" ; dispatch movewindowpixel exact ${scriptX} ${scriptY},address:$addr"
      hyprctl --batch "$b"
    fi
  '';
in {
  options.modules.hyprland.pip = {
    size = {
      width = lib.mkOption {
        type = lib.types.int;
        default = 960;
        description = "PiP window width in pixels.";
      };
      height = lib.mkOption {
        type = lib.types.int;
        default = 540;
        description = "PiP window height in pixels.";
      };
    };

    corner = lib.mkOption {
      type = lib.types.enum ["top-right" "top-left" "bottom-right" "bottom-left"];
      default = "top-right";
      description = "Screen corner where PiP windows are placed.";
    };

    margin = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Distance from monitor edge in pixels.";
    };

    respectSourceSize = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        For browser PiP windows, skip the size-enforcement windowrule so the
        browser keeps the video's native aspect ratio (no letterboxing). The
        manual `toggleKey` toggle still uses `size.{width,height}` since it
        applies to arbitrary windows, not video.
      '';
    };

    opacity = {
      focused = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Opacity when focused (0.0–1.0).";
      };
      unfocused = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = ''
          Opacity when unfocused (0.0–1.0). Defaults to 1.0 because video
          content looks wrong with transparency; lower it only for chrome-style
          PiP.
        '';
      };
      override = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Append the `override` keyword to opacity rules so they win over the
          global `inactive_opacity` setting. Required for fully-opaque PiP
          when the global setting is <1.0.
        '';
      };
    };

    pinned = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pin PiP windows across all workspaces (macOS PiP behavior).";
    };

    rounding = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Per-window rounding for PiP (null = inherit global decoration.rounding).";
    };

    borderSize = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Per-window border size for PiP (null = inherit global general.border_size).";
    };

    activeBorderColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "rgba(ffffff60)";
      description = ''
        Override active border color for PiP. Format matches Hyprland color
        strings (e.g. `rgba(ffffff60)` or `rgb(ffffff)`).
      '';
    };

    inactiveBorderColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Override inactive border color for PiP. Only applied if
        `activeBorderColor` is also set (Hyprland's `bordercolor` rule expects
        both or one color).
      '';
    };

    titleRegex = lib.mkOption {
      type = lib.types.str;
      default = "^(Picture[- ]in[- ][Pp]icture)$";
      description = ''
        Regex matching browser PiP window titles. Default covers
        Firefox/Chromium spelling variants.
      '';
    };

    toggleKey = lib.mkOption {
      type = lib.types.str;
      default = "SUPER,p";
      example = "SUPER SHIFT,p";
      description = ''
        Hyprland bind prefix for the manual PiP toggle (applies to whatever
        window is currently active). Format: "MODS,KEY".
      '';
    };
  };

  # Picture-in-Picture: float, optionally pin across workspaces, park in the
  # configured corner. Title-matched rules apply automatically to browser PiP
  # windows. The toggle bind invokes the same treatment on any active window
  # via pip-toggle, and a second press restores the saved state.
  config.wayland.windowManager.hyprland.settings = {
    windowrule =
      [
        "float on, ${matchTitle}"
        # `move` resolves monitor_w/monitor_h per-monitor. With size enforced,
        # the move math uses the literal width/height to dodge the race where
        # `window_w` resolves to the browser's initial request before `size`
        # applies. With respectSourceSize=true the move math instead reads
        # `window_w`/`window_h` directly so placement stays correct for any
        # aspect ratio.
        "move ${moveExpr}, ${matchTitle}"
        "${opacityRule}, ${matchTitle}"
        # Browsers tear down and recreate the PiP surface on video transitions
        # (auto-play next, source switch). Each recreate is a new-window
        # event that can pull focus away from a fullscreen window (e.g.
        # Minecraft) and cause Hyprland to drop its fullscreen state. Block
        # initial focus and any later activate/fullscreen requests from PiP.
        "no_initial_focus on, ${matchTitle}"
        "suppress_event activate activatefocus fullscreen maximize fullscreenoutput, ${matchTitle}"
      ]
      ++ lib.optional (!cfg.respectSourceSize) "size ${toString cfg.size.width} ${toString cfg.size.height}, ${matchTitle}"
      ++ lib.optional cfg.pinned "pin on, ${matchTitle}"
      ++ lib.optional (cfg.rounding != null) "rounding ${toString cfg.rounding}, ${matchTitle}"
      ++ lib.optional (cfg.borderSize != null) "bordersize ${toString cfg.borderSize}, ${matchTitle}"
      ++ lib.optional (cfg.activeBorderColor != null) "bordercolor ${cfg.activeBorderColor}${
        lib.optionalString (cfg.inactiveBorderColor != null) " ${cfg.inactiveBorderColor}"
      }, ${matchTitle}";

    bind = [
      "${cfg.toggleKey},exec,${pip-toggle}/bin/hypr-pip-toggle"
    ];
  };
}
