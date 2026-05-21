# Screenshot setup — direct slurp + grim pipeline with a cursor-hide guard
# around the screencopy call.
#
# Background: NVIDIA hosts set `cursor.no_hardware_cursors = true` (see
# ./nvidia.nix). With software cursors, the cursor is composited into the
# framebuffer that wlr-screencopy reads, so it appears in screenshots.
# Confirmed via testing that NEITHER `cursor:invisible 1` nor toggling
# `cursor:no_hardware_cursors 0` at runtime removes the cursor from
# screencopy frames — the only mechanism that works is physically moving
# the cursor off-screen via `hyprctl dispatch movecursor`. Hyprland accepts
# negative coordinates and doesn't clamp them.
#
# Why we don't wrap hyprshot: hyprshot's Nix wrapper forcefully prepends
# grim's real /nix/store path to PATH on every invocation, so PATH-shadow
# tricks (drop a `grim` script in front of PATH) don't work — hyprshot
# always reaches the real grim. Reimplementing the three modes (region,
# output, window) is shorter than fighting the wrapper.
#
# Also drops the active-window border for the capture instant so the
# soft-white focus-glow doesn't end up in screenshots.
{pkgs, ...}: let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [hyprland slurp grim wl-clipboard libnotify jq coreutils];
    text = ''
      mode="region"
      while [ $# -gt 0 ]; do
        case "$1" in
          -m|--mode) mode="$2"; shift 2 ;;
          *) shift ;;
        esac
      done

      # Pick the capture geometry. Slurp's selection UI runs with the cursor
      # fully visible; we only hide it later, around the actual grim call.
      case "$mode" in
        region)
          if ! geometry=$(slurp); then exit 0; fi
          ;;
        output)
          geometry=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.x),\(.y) \(.width)x\(.height)"')
          ;;
        window)
          geometry=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          ;;
        *)
          echo "usage: screenshot -m {region|output|window}" >&2
          exit 1
          ;;
      esac

      # Snapshot cursor + border state, set up the EXIT trap before any
      # mutation so we always restore even on grim failure or Ctrl-C.
      pos=$(hyprctl cursorpos | tr -d ' ')
      cx=''${pos%,*}
      cy=''${pos#*,}
      border_was=$(hyprctl getoption general:border_size -j | jq -r '.int')
      restore() {
        hyprctl --batch "dispatch movecursor $cx $cy ; keyword general:border_size $border_was" >/dev/null
      }
      trap restore EXIT

      # Park cursor off-screen and zero the border. 50ms is plenty for the
      # cursor-less frame to render on any sane monitor (60Hz = 16.7ms).
      hyprctl --batch "dispatch movecursor -10000 -10000 ; keyword general:border_size 0" >/dev/null
      sleep 0.05

      # Capture to file, copy to clipboard, notify.
      outdir="$HOME/Pictures"
      mkdir -p "$outdir"
      outfile="$outdir/$(date +%Y-%m-%d_%H-%M-%S).png"
      grim -g "$geometry" "$outfile"
      wl-copy --type image/png < "$outfile"
      notify-send "Screenshot saved" "$outfile" -i "$outfile" -t 5000 -a screenshot
    '';
  };
in {
  wayland.windowManager.hyprland.settings = {
    bind = [
      # PRINT               Screenshot focused monitor
      # SUPER+PRINT         Screenshot region
      ",PRINT,exec,${screenshot}/bin/screenshot -m output"
      "SUPER,PRINT,exec,${screenshot}/bin/screenshot -m region"
    ];

    # Kill the slurp selection-rectangle close animation. Without this,
    # region screenshots can occasionally capture the half-faded selection
    # box because screencopy reads the framebuffer before the layer's exit
    # animation completes. Documented workaround from hyprwm/contrib#60.
    #
    # Hyprland 0.50+ renamed `noanim` → `no_anim` and now requires an
    # explicit `on` value (same migration that hit `blur` → `blur on`).
    layerrule = [
      "no_anim on, match:namespace selection"
    ];
  };
}
