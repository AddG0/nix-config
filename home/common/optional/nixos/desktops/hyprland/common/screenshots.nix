# Screenshot setup: direct slurp + grim pipeline with a cursor-hide guard
# around the screencopy call.
#
# Software-cursor hosts (NVIDIA forces this, see ./nvidia.nix) composite the
# cursor into the framebuffer wlr-screencopy reads, so grim captures it. To hide
# it we flip to hardware cursors for the capture (grim excludes the HW overlay
# plane), then flip back. The flip only lands on the next cursor motion, so we
# nudge the cursor 1px. Hosts that already default to hardware cursors skip all
# of this: grim excludes their cursor natively.
#
# Trade-off: after flipping back, the software cursor stays invisible until the
# next real pointer motion (0.55 won't redraw a warped software cursor; every
# config-poke redraw, incl. a zoom_factor nudge, is a no-op or frame-racy).
# Moving the mouse brings it back; we don't try to force it.
#
# Rejected: `cursor:invisible 1` doesn't drop it from screencopy; parking it
# off-screen with `movecursor` fails (0.55 clamps to the layout, and a single
# monitor has no spot outside a full-screen shot); a headless output adds space
# but reshuffles workspaces.
#
# Why we don't wrap hyprshot: hyprshot's Nix wrapper forcefully prepends
# grim's real /nix/store path to PATH on every invocation, so PATH-shadow
# tricks (drop a `grim` script in front of PATH) don't work; hyprshot
# always reaches the real grim. Reimplementing the three modes (region,
# output, window) is shorter than fighting the wrapper.
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

      case "$mode" in
        region)
          if ! geometry=$(slurp); then exit 0; fi
          grim_target=(-g "$geometry")
          ;;
        output)
          # By output name, not geometry: a hand-built geometry mixes logical
          # position with physical size and breaks on scaled monitors.
          name=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
          grim_target=(-o "$name")
          ;;
        window)
          geometry=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          grim_target=(-g "$geometry")
          ;;
        *)
          echo "usage: screenshot -m {region|output|window}" >&2
          exit 1
          ;;
      esac

      # Set the EXIT trap before mutating anything, so state is restored even
      # on grim failure or Ctrl-C.
      pos=$(hyprctl cursorpos | tr -d ' ')
      cx=''${pos%,*}
      cy=''${pos#*,}
      border_was=$(hyprctl getoption general:border_size -j | jq -r '.int')
      hwcursor_was=$(hyprctl getoption cursor:no_hardware_cursors -j | jq -r '.int')
      restore() {
        hyprctl --batch "keyword cursor:no_hardware_cursors $hwcursor_was ; dispatch movecursor $cx $cy ; keyword general:border_size $border_was" >/dev/null
      }
      trap restore EXIT

      # Drop the active-window border so its focus-glow stays out of the shot.
      hyprctl keyword general:border_size 0 >/dev/null

      # Software-cursor hosts only: flip to hardware cursors so grim excludes
      # the cursor, nudging 1px to land the switch. HW-cursor hosts skip this;
      # grim already excludes their cursor. See the header on reshow after.
      if [ "$hwcursor_was" = 1 ]; then
        hyprctl keyword cursor:no_hardware_cursors 0 >/dev/null
        hyprctl dispatch movecursor $((cx + 1)) "$cy" >/dev/null
      fi
      sleep 0.05

      outdir="$HOME/Pictures/Screenshots"
      mkdir -p "$outdir"
      outfile="$outdir/$(date +%Y-%m-%d_%H-%M-%S).png"
      grim "''${grim_target[@]}" "$outfile"
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
