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
{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors;
  # Freeze only $HYPRPICKER_OUTPUT, so the region overlay covers just the monitor under the cursor.
  # The extra roundtrip delivers wl_output names, which the stock loop runs before.
  hyprpicker = pkgs.hyprpicker.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/hyprpicker.cpp --replace-fail \
          'for (auto& m : m_vMonitors) {' \
          'wl_display_roundtrip(m_pWLDisplay); for (auto& m : m_vMonitors) { if (const char* only = getenv("HYPRPICKER_OUTPUT"); only && m->name != only) continue;'
      '';
  });
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = [hyprpicker] ++ (with pkgs; [hyprland slurp grim wl-clipboard libnotify jq coreutils imagemagick]);
    text = ''
      mode="region"
      while [ $# -gt 0 ]; do
        case "$1" in
          -m|--mode) mode="$2"; shift 2 ;;
          *) shift ;;
        esac
      done

      # One hyprctl round-trip; mon is the monitor under the cursor, not the focused one.
      IFS=$'\t' read -r cx cy hwcursor_was border shadow border_idle shadow_idle anims_was mon < <(
        hyprctl --batch -j "cursorpos ; getoption cursor:no_hardware_cursors ; getoption general:col.active_border ; getoption decoration:shadow:color ; getoption general:col.inactive_border ; getoption decoration:shadow:color_inactive ; getoption animations:enabled ; monitors" | jq -sr '
          # getoption prints bare AARRGGBB, which keyword only parses with a 0x prefix.
          def grad: .custom | split(" ") | map(if endswith("deg") then . else "0x" + . end) | join(" ");
          def col: "0x" + (.custom | split(" ")[0]);
          .[0] as $c
          | (.[7] | map(select($c.x >= .x and $c.x < .x + .width / .scale and $c.y >= .y and $c.y < .y + .height / .scale))[0]
              // (.[7][] | select(.focused))) as $m
          | [$c.x, $c.y, .[1].int, (.[2] | grad), (.[3] | col), (.[4] | grad), (.[5] | col), .[6].int, ($m | tojson)] | @tsv'
      )
      if [ -z "$mon" ]; then
        notify-send "Screenshot failed" "No monitor found under the cursor (hyprctl/jq lookup failed)" -t 5000 -a screenshot
        exit 1
      fi
      name=$(jq -r '.name' <<<"$mon")

      case "$mode" in
        region) ;;
        output)
          # By output name, not geometry: a hand-built geometry mixes logical
          # position with physical size and breaks on scaled monitors.
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
      freeze_pid=""
      restore() {
        if [ -n "$freeze_pid" ]; then kill "$freeze_pid" 2>/dev/null || true; fi
        hyprctl --batch "keyword cursor:no_hardware_cursors $hwcursor_was ; dispatch movecursor $cx $cy ; keyword animations:enabled $anims_was ; keyword general:col.active_border $border ; keyword decoration:shadow:color $shadow" >/dev/null
      }
      trap restore EXIT

      # Draw the focused window as unfocused, so its highlight stays out of the shot
      # without touching focus; animations off so the border doesn't fade mid-capture. Software-cursor hosts also flip to hardware cursors so
      # grim excludes the cursor, nudging 1px to land the switch. See the header on reshow after.
      unfocus="keyword animations:enabled 0 ; keyword general:col.active_border $border_idle ; keyword decoration:shadow:color $shadow_idle"
      if [ "$hwcursor_was" = 1 ]; then
        hyprctl --batch "$unfocus ; keyword cursor:no_hardware_cursors 0 ; dispatch movecursor $((cx + 1)) $cy" >/dev/null
      else
        hyprctl --batch "$unfocus" >/dev/null
      fi
      sleep 0.05

      outdir="$HOME/Pictures/Screenshots"
      mkdir -p "$outdir"
      outfile="$outdir/$(date +%Y-%m-%d_%H-%M-%S).png"

      if [ "$mode" = region ]; then
        # Capture before slurp clears hover; never through the freeze, which darkens on HDR outputs.
        frame=$(mktemp --suffix=.ppm)
        trap 'rm -f "$frame"; restore' EXIT
        grim -t ppm -o "$name" "$frame"
        HYPRPICKER_OUTPUT="$name" hyprpicker -r -z >/dev/null 2>&1 &
        freeze_pid=$!
        # slurp must map after the freeze, or the freeze stacks over its selection box.
        for _ in $(seq 100); do
          hyprctl layers -j | jq -e '[.. | objects | select(.namespace? == "hyprpicker")] | length > 0' >/dev/null && break
          sleep 0.01
        done
        # Transparent background keeps the other outputs untouched, so the box carries its own contrast.
        if ! geometry=$(slurp -b "#00000000" -c "#${c.base0D}ff" -s "#${c.base0D}33" -w 2); then exit 0; fi
        # Crop to the frozen monitor in native pixels; a region spilling past it is clipped.
        crop=$(jq -r --arg g "$geometry" '
          ($g | capture("(?<x>-?[0-9]+),(?<y>-?[0-9]+) (?<w>[0-9]+)x(?<h>[0-9]+)") | map_values(tonumber)) as $r
          | ([$r.x, .x] | max) as $x0 | ([$r.y, .y] | max) as $y0
          | ([$r.x + $r.w, .x + .width / .scale] | min) as $x1 | ([$r.y + $r.h, .y + .height / .scale] | min) as $y1
          | if $x1 <= $x0 or $y1 <= $y0 then empty
            else "\(($x1 - $x0) * .scale | round)x\(($y1 - $y0) * .scale | round)+\(($x0 - .x) * .scale | round)+\(($y0 - .y) * .scale | round)" end
        ' <<<"$mon")
        if [ -z "$crop" ]; then
          notify-send "Screenshot skipped" "Selection $geometry is outside $name" -t 5000 -a screenshot
          exit 0
        fi
        magick "$frame" -crop "$crop" +repage "$outfile"
      else
        grim "''${grim_target[@]}" "$outfile"
      fi
      wl-copy --type image/png < "$outfile"
      notify-send "Screenshot saved" "$outfile" -i "$outfile" -t 5000 -a screenshot
    '';
  };
in {
  wayland.windowManager.hyprland.settings = {
    bind = [
      # PRINT               Screenshot monitor under the cursor
      # SUPER+PRINT         Screenshot region
      ",PRINT,exec,${screenshot}/bin/screenshot -m output"
      "SUPER,PRINT,exec,${screenshot}/bin/screenshot -m region"
    ];
    # Freeze and slurp ("selection") must appear and vanish instantly, not slide over the screen.
    layerrule = ["no_anim on, match:namespace ^(hyprpicker|selection)$"];
  };
}
