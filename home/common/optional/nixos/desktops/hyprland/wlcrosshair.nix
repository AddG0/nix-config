{
  lib,
  pkgs,
  ...
}: let
  # Cyan plus with a 2-pixel black outline, no centre dot. 64x64 PNG.
  # Arms 4 thick, 10 long, 6-pixel gap from centre on each side.
  # Nearest-neighbour blit: draw at the on-screen `size` or arms come out uneven.
  # Even canvas and even arm thickness: the sprite's centre falls on a pixel
  # boundary, which is where the compositor centres it on an even-width output.
  # The outline is what carries contrast where the arms match the background —
  # Overwatch's blue team outlines, skyboxes and water all sit near cyan.
  # #00E0E0 instead of pure #00FFFF: on the 10-bit HDR pipeline the per-
  # channel sRGB→wide-gamut conversion of max-value channels at 2-pixel
  # widths splits into visible RGB fringing. Keeping the lit channels below
  # max (E0, not FF) avoids the chromatic split.
  crosshair =
    pkgs.runCommand "crosshair.png" {
      nativeBuildInputs = [pkgs.imagemagick];
    } ''
      # PNG32: force RGBA + sRGB encoding. Without this, ImageMagick auto-
      # detects equal RGB channels and saves as grayscale, which Hyprland's
      # HDR pipeline appears to mis-convert into chromatically split colors.
      magick -size 64x64 xc:none \
        -fill '#000000' \
        -draw 'rectangle 28,14 35,27' \
        -draw 'rectangle 28,36 35,49' \
        -draw 'rectangle 14,28 27,35' \
        -draw 'rectangle 36,28 49,35' \
        -fill '#00E0E0' \
        -draw 'rectangle 30,16 33,25' \
        -draw 'rectangle 30,38 33,47' \
        -draw 'rectangle 16,30 25,33' \
        -draw 'rectangle 38,30 47,33' \
        -define png:color-type=6 PNG32:"$out"
    '';

  image = "${crosshair}";

  # SUPER+SHIFT+C: show the crosshair on the monitor of the active workspace.
  # - No config change → toggle visibility.
  # - Config change (monitor / image path / size) → rewrite config, reload
  #   (rebinds the layer surface and reloads image), force visible.
  toggle = pkgs.writeShellApplication {
    name = "wlcrosshair-toggle-here";
    runtimeInputs = with pkgs; [wlcrosshair hyprland jq coreutils procps util-linux];
    text = ''
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/wlcrosshair"
      config="$config_dir/config.toml"
      socket="/tmp/crosshair.sock"
      image=${lib.escapeShellArg image}
      size="''${WLCROSSHAIR_SIZE:-64}"

      mkdir -p "$config_dir"

      mon=$(hyprctl activeworkspace -j | jq -r '.monitor // empty')
      if [ -z "$mon" ]; then
        mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
      fi
      if [ -z "$mon" ]; then
        echo "wlcrosshair-toggle-here: could not determine active monitor" >&2
        exit 1
      fi

      desired=$(printf 'path = "%s"\noutput = "%s"\nsize = %s\n' "$image" "$mon" "$size")
      current=""
      [ -f "$config" ] && current=$(cat "$config")

      changed=0
      if [ "$desired" != "$current" ]; then
        printf '%s' "$desired" > "$config"
        changed=1
      fi

      if pgrep -x wlcrosshair >/dev/null 2>&1; then
        if [ "$changed" = 1 ]; then
          # reload rebinds the surface and reloads the image; show overrides
          # preserved visibility. The daemon handles each IPC connection in
          # its own goroutine without locking, so reload and show can race
          # (show attaches NULL buffer while reload is tearing down) — sleep
          # long enough for reload's wayland roundtrips to complete.
          wlcrosshairctl reload
          sleep 0.2
          wlcrosshairctl show
        else
          wlcrosshairctl toggle
        fi
      else
        setsid -f wlcrosshair >/dev/null 2>&1
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          [ -S "$socket" ] && break
          sleep 0.05
        done
        if [ ! -S "$socket" ]; then
          echo "wlcrosshair-toggle-here: daemon failed to start" >&2
          exit 1
        fi
        wlcrosshairctl show
      fi
    '';
  };
in {
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPERSHIFT,c,exec,${toggle}/bin/wlcrosshair-toggle-here"
    ];
    # - blur off: avoid Hyprland blurring the layer (see-through smear).
    # - animation none: each reload destroys/recreates the surface; without
    #   this, Hyprland slides it in from the screen edge on every monitor
    #   switch.
    layerrule = [
      "blur off, match:namespace wlcrosshair"
      "animation none, match:namespace wlcrosshair"
    ];
  };
}
