{pkgs, ...}: let
  # SUPER+P toggles browser-style PiP on the active window: float, pin,
  # 960x540 top-right (20px margin). Press again on the same window to
  # restore its saved state. Marker file keyed by window address.
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
      read -r mx my mw < <(
        hyprctl monitors -j | jq -r --argjson i "$mon" '.[]|select(.id==$i)|[.x,.y,.width]|@tsv'
      )
      printf '%s %s %s %s %s %s\n' "$fl" "$pin" "$x" "$y" "$w" "$h" > "$f"
      b=""
      [ "$fl"  != true ] && b+="dispatch togglefloating address:$addr ; "
      [ "$pin" != true ] && b+="dispatch pin address:$addr ; "
      b+="dispatch resizewindowpixel exact 960 540,address:$addr"
      b+=" ; dispatch movewindowpixel exact $((mx+mw-980)) $((my+20)),address:$addr"
      hyprctl --batch "$b"
    fi
  '';
in {
  # Picture-in-Picture: float, pin across workspaces, park top-right.
  # Title-matched rules apply automatically to Firefox/Chromium PiP windows.
  # SUPER+P invokes the same treatment on any active window via pip-toggle.
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float on, match:title ^(Picture[- ]in[- ][Pp]icture)$"
      "pin on, match:title ^(Picture[- ]in[- ][Pp]icture)$"
      "size 960 540, match:title ^(Picture[- ]in[- ][Pp]icture)$"
      # Top-right with 20px margin. `window_w` resolves to the browser's initial
      # PiP request (set from the source video) before the size rule above takes
      # effect, so for wide sources it lands on the left. Use the literal 960 to
      # match the size rule and keep placement deterministic.
      "move (monitor_w-960-20) 20, match:title ^(Picture[- ]in[- ][Pp]icture)$"
      # Override global inactive_opacity so PiP stays fully opaque while unfocused.
      "opacity 1.0 override 1.0 override, match:title ^(Picture[- ]in[- ][Pp]icture)$"
      # Browsers tear down and recreate the PiP surface on video transitions
      # (auto-play next, source switch). Each recreate is a new-window event
      # that can pull focus away from a fullscreen window (e.g. Minecraft) and
      # cause Hyprland to drop its fullscreen state. Block initial focus and
      # any later activate/fullscreen requests from the PiP itself.
      "no_initial_focus on, match:title ^(Picture[- ]in[- ][Pp]icture)$"
      "suppress_event activate activatefocus fullscreen maximize fullscreenoutput, match:title ^(Picture[- ]in[- ][Pp]icture)$"
    ];

    bind = [
      "SUPER,p,exec,${pip-toggle}/bin/hypr-pip-toggle"
    ];
  };
}
