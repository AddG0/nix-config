# Hyprland visual config — Material Design 3.
#
# Design pillars:
#   1. Depth from tonal elevation + shadow, never translucency or blur.
#   2. Circular corners — rounding_power 2.0; M3 never draws a superellipse.
#   3. State is carried by the primary accent, not a neutral tint.
#   4. Enter decelerates, exit accelerates. The asymmetry is the spec.
#
# mkForce calls below override two upstream sources:
#   - settings.nix in ../common sets gaps_in / gaps_out to 5/10
#   - stylix's hyprland target auto-themes col.active_border,
#     col.inactive_border, decoration.shadow.color, and background_color
#     from base16; the roles we want don't match its base0D/base03/base00 picks.
{
  lib,
  config,
  ...
}: let
  c = config.lib.stylix.colors;
  # M3 colour roles on base16, bare hex for hyprland's rgba(). Catppuccin's
  # ramp is base02/03/04 (surface0/1/2) — base01 is `mantle`, darker than
  # base00. Check a new scheme ramps upward before reusing these.
  surfaceContainer = c.base02;
  outline = c.base04;
  outlineVariant = c.base03;
  onSurface = c.base05;
  onSurfaceVariant = lib.removePrefix "#" config.lib.palette.muted.text; # base04 is 2.46:1 — too dim for text
  primary = c.base0D;
  error = c.base08;
  tertiary = c.base0A;
  sans = config.stylix.fonts.sansSerif.name;
  # Stylix-driven desktop text size — same value the bar and notifications use,
  # so hy3 tab labels match the rest of the system chrome.
  desktopFontSize = config.stylix.fonts.sizes.desktop;
  # M3 "large" step, shared by window decoration, hy3 tabs and the noctalia bar.
  windowRounding = 16;
  # Deciseconds (Hyprland's unit), a step under M3's 200/300/400 scale: the
  # spec targets touch, where longer reads as considered rather than as lag.
  short = 1; # 100ms
  medium = 2; # 200ms
  long = 3; # 300ms
  # Reused as the noctalia bar margin so bar and window edges align.
  edgeGap = 8;
in {
  wayland.windowManager.hyprland.settings = {
    general = {
      # A hairline is a weak focus cue at gaps_in 4, and Hyprland stair-steps
      # a 1px arc on a 16px radius.
      border_size = 2;
      gaps_in = lib.mkForce 4;
      gaps_out = lib.mkForce edgeGap;
      "col.active_border" = lib.mkForce "rgba(${primary}ff)";
      # outline, not outline-variant: base03 is 1.80:1 against base00 and
      # effectively invisible; base04 is 2.46:1.
      "col.inactive_border" = lib.mkForce "rgba(${outline}ff)";
    };

    decoration = {
      rounding = windowRounding;
      rounding_power = 2.0;
      active_opacity = 1.0;
      inactive_opacity = 1.0;
      fullscreen_opacity = 1.0;

      # ~M3 elevation 4. render_power 2's quick falloff keeps the shadow
      # attached to the window edge instead of spreading into a halo.
      shadow = {
        enabled = true;
        range = 20;
        render_power = 2;
        offset = "0 5";
        color = lib.mkForce "rgba(00000066)";
        color_inactive = "rgba(00000033)";
        scale = 0.97;
      };

      # M3 scrim behind a modal surface is 32% black.
      dim_special = 0.32;

      # Also makes any `blur on` layerrule a no-op, hence none are declared.
      blur.enabled = false;
    };

    # hy3 tab-group styling (Super+G toggles a tabbed group), shaped as an M3
    # segmented button.
    #
    # Color-key syntax is version-dependent. For hy3 <= 0.54.x (current), the
    # canonical keys are flat dotted at the tabs level:
    #   col.active        col.active.border        col.active.text
    # Master branch moved them under a `colors { ... }` subsection with
    # snake_case names — that syntax is silently ignored on 0.54.x. If you bump
    # hy3 past the rename, swap the keys back to `colors.*`. Verify with
    # `hyprctl getoption plugin:hy3:tabs:col.active.border` — `set: true` means
    # it bound.
    plugin.hy3.tabs = {
      # radius == height/2 gives M3 "full" shape; reusing windowRounding keeps
      # tab and window corners on one knob.
      height = 32;
      padding = 6;
      radius = windowRounding;
      border_width = 1;
      render_text = true;
      text_center = true;
      # M3 label-large is Medium (500).
      text_font = "${sans} Medium";
      text_height = desktopFontSize;
      # text_padding is left-padding only (no-op with text_center = true).

      # Slide in from above the window — reads as a header attached to the
      # group rather than a popup rising from below the content.
      from_top = true;

      blur = false;
      opacity = 1.0;

      "col.active" = "rgba(${primary}33)";
      "col.active.border" = "rgba(${primary}ff)";
      "col.active.text" = "rgba(${primary}ff)";

      "col.active_alt_monitor" = "rgba(${primary}1a)";
      "col.active_alt_monitor.border" = "rgba(${outline}ff)";
      "col.active_alt_monitor.text" = "rgba(${onSurface}ff)";

      # hy3 "focused" = group has focus but this tab isn't the active one.
      "col.focused" = "rgba(${primary}1a)";
      "col.focused.border" = "rgba(${outline}ff)";
      "col.focused.text" = "rgba(${onSurface}ff)";

      "col.inactive" = "rgba(${surfaceContainer}ff)";
      "col.inactive.border" = "rgba(${outlineVariant}ff)";
      "col.inactive.text" = "rgba(${onSurfaceVariant}ff)";

      # The one role that breaks the accent pattern — urgency must read instantly.
      "col.urgent" = "rgba(${error}ff)";
      "col.urgent.border" = "rgba(${error}ff)";
      "col.urgent.text" = "rgba(${c.base00}ff)";

      # Set by hy3:locktab; tertiary keeps "pinned" distinct from selected/urgent.
      "col.locked" = "rgba(${tertiary}33)";
      "col.locked.border" = "rgba(${tertiary}ff)";
      "col.locked.text" = "rgba(${tertiary}ff)";
    };

    misc = {
      # Animate resize but not drag. Dragging feels native when snappy;
      # resizing benefits from a smooth interpolation.
      animate_manual_resizes = true;
      animate_mouse_windowdragging = false;
      # Terminal hides when it launches a GUI app (e.g. `firefox &` from
      # ghostty hides ghostty until firefox closes). Disable if you launch
      # GUIs from tmux and find this jarring.
      enable_swallow = true;
      swallow_regex = "^(ghostty|kitty|Alacritty|foot|wezterm)$";
      # On focus request while fullscreen: un-fullscreen, then focus. Stacking
      # behavior (default 0) feels broken here.
      # (Renamed from new_window_takes_over_fullscreen in Hyprland 0.50+.)
      on_focus_under_fullscreen = 2;
      # Apps stop yanking focus when they want attention — they get an
      # urgency hint instead. Major quality-of-life win.
      focus_on_activate = false;
      # Solid dark color behind windows. Eliminates the brief flash before
      # wpaperd loads the wallpaper. Tracks stylix base00 so it stays in
      # sync with theme changes — stylix's hyprland target also sets this
      # to rgb(base00), but home-manager flags any redefinition as a
      # conflict, so we mkForce.
      background_color = lib.mkForce "0xff${c.base00}";
    };

    # Three-finger swipe between workspaces. Only triggers if a touchpad is
    # present, so safe to define globally.
    #
    # Hyprland 0.50+ split this into two parts:
    #   - `gesture = N, direction, dispatcher` enables it (replaces the old
    #     `workspace_swipe = true` + `workspace_swipe_fingers = N`).
    #   - `gestures { ... }` block holds the live-swipe tuning knobs.
    gesture = [
      "3, horizontal, workspace"
    ];
    gestures = {
      # ~400px feels right; 300 is too sensitive, 500+ is sluggish.
      workspace_swipe_distance = 400;
      # Assumes natural-scroll touchpads. If a host disables natural scroll
      # system-wide, swipes will feel inverted — override per-host in that case.
      workspace_swipe_invert = true;
      # Lower = flicks more reliable; 30 (default) is sluggish.
      workspace_swipe_min_speed_to_force = 15;
      # Past halfway commits, otherwise springs back.
      workspace_swipe_cancel_ratio = 0.5;
      workspace_swipe_create_new = false;
      # Keep swiping past first workspace without snapping.
      workspace_swipe_forever = true;
      workspace_swipe_direction_lock = true;
      # Use real workspace indices so 1->2->3 feels linear (the
      # underrated knob — dispatcher order can be non-monotonic).
      workspace_swipe_use_r = true;
    };

    animations = {
      enabled = true;
      # M3 easing tokens. The enter/exit split is what reads as Material
      # rather than as generically smooth motion.
      bezier = [
        "emphasized, 0.2, 0, 0, 1"
        "emphasizedDecelerate, 0.05, 0.7, 0.1, 1"
        "emphasizedAccelerate, 0.3, 0, 0.8, 0.15"
      ];
      # Retune speed via the short/medium/long tokens, not these lines.
      animation = [
        "windows, 1, ${toString medium}, emphasizedDecelerate, popin 92%"
        "windowsOut, 1, ${toString short}, emphasizedAccelerate, popin 92%"
        "fadeIn, 1, ${toString medium}, emphasizedDecelerate"
        "fadeOut, 1, ${toString short}, emphasizedAccelerate"
        # Focus-transition events.
        "fadeSwitch, 1, ${toString short}, emphasized"
        "fadeShadow, 1, ${toString medium}, emphasized"
        "fadeDim, 1, ${toString short}, emphasized"
        "workspaces, 1, ${toString medium}, emphasized, slidefade 20%"
        # The one transition that reads better slightly slower — it slides the
        # full height of the screen and looks broken when it snaps.
        "specialWorkspace, 1, ${toString long}, emphasizedDecelerate, slidefadevert -100%"
        "layersIn, 1, ${toString medium}, emphasizedDecelerate, slide"
        "layersOut, 1, ${toString short}, emphasizedAccelerate, slide"
        "fadeLayersIn, 1, ${toString short}, emphasizedDecelerate"
        "fadeLayersOut, 1, ${toString short}, emphasizedAccelerate"
        "border, 1, ${toString short}, emphasized"
      ];
    };
  };

  # stylix maps this to base04 — 2.46:1 as label text. The muted tone is 7.37:1.
  programs.noctalia.customPalettes.stylix.dark.mOnSurfaceVariant =
    lib.mkForce config.lib.palette.muted.text;

  # Noctalia shape/layout; colors and fonts come from stylix's noctalia target.
  programs.noctalia.settings = {
    shell.shadow.direction = "down";

    bar.main = {
      margin_ends = edgeGap; # Align bar ends with window outer gap.
      margin_edge = edgeGap; # Match so top spacing equals the sides.
      radius = windowRounding; # Same source of truth as windows + tabs.
      capsule = true; # M3 pill-shaped widget containers.
      border_width = 0; # Elevation does the framing, not a border.
      # stylix routes opacity.desktop to the dock and never sets bar opacity.
      background_opacity = config.stylix.opacity.desktop;
      widget_spacing = 6;
      padding = 4;
      shadow = true;
    };
  };

  # Hyprlock styling lives in ./hyprlock.nix.
}
