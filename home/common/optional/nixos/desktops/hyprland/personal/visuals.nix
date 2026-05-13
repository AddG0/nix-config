# Hyprland visual config — macOS-leaning aesthetic.
#
# Design pillars:
#   1. Depth via shadows, not borders. Hairline borders + soft drop shadow
#      communicate focus; thick colored frames fight the rounded corners.
#   2. Frosted-glass blur on panels/menus (Big Sur look). Vibrancy + noise
#      mimic Apple's saturation boost and grain.
#   3. Squircle corners (rounding_power 3.0) — Apple's superellipse, not a
#      plain circular arc.
#   4. Animations should feel deliberate, not snappy. Slight overshoot on
#      window opens; clean ease-out (no overshoot) on workspace slides.
#   5. Asymmetric timings on layers: IN slower with overshoot, OUT fast.
#
# Several values are mkForce'd because the catppuccin/nix hyprland module
# also sets them — without mkForce, evaluation fails with a conflict.
{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.hyprland.settings = {
    # Catppuccin Mocha palette via raw hyprland.conf source. Loaded first so
    # our explicit Nix-defined colors below (mkForce'd) override it.
    source = [
      "${pkgs.themes.catppuccin.hyprland}/themes/mocha.conf"
    ];

    general = {
      # 1px hairline. macOS uses ~1px; 4px competes with the drop shadow.
      border_size = 1;
      # Tight gaps so shadows are visible without screaming "tiling WM".
      # Overrides settings.nix defaults of 5/10.
      gaps_in = lib.mkForce 4;
      gaps_out = lib.mkForce 8;
      # Near-invisible white gradient on focus — focus is communicated by
      # shadow/opacity, not by the border itself.
      "col.active_border" = lib.mkForce "rgba(ffffff40) rgba(ffffff10) 45deg";
      "col.inactive_border" = lib.mkForce "rgba(00000020)";
    };

    decoration = {
      # macOS windows are ~10–12px. 14 read as "Linux trying too hard".
      rounding = 12;
      # Squircle exponent (Hyprland >=0.45). 2.0 = circular arc; 3.0 = Apple
      # superellipse — corners look slightly "fatter" near the midpoint.
      rounding_power = 3.0;
      active_opacity = 1.0;
      inactive_opacity = 0.9;
      fullscreen_opacity = 1.0;

      # Drop shadow is the single biggest macOS-feel win. Pure-vertical
      # offset (Apple never offsets horizontally), gentle range, alpha-only
      # color (never pure black — looks like Windows 7).
      shadow = {
        enabled = true;
        range = 30; # 20–40 is the sweet spot; higher = softer but more GPU.
        render_power = 3; # 1–4 falloff curve; 3 matches Apple's gentle fade.
        offset = "0 8"; # Apple uses ~8–12px down, 0 horizontal.
        color = lib.mkForce "rgba(00000055)"; # ~33% black.
        color_inactive = lib.mkForce "rgba(00000028)"; # Lighter — subtle focus cue.
        scale = 0.97; # Slight shrink so shadow doesn't bleed past rounded corners.
      };

      # Frosted glass. Big Sur uses ~30px Gaussian; size 8 + passes 3
      # approximates it. vibrancy + noise are end-4's widely-copied magic
      # numbers: vibrancy saturates the blurred content (Apple "vibrancy"),
      # noise hides banding on gradients (imperceptible film grain).
      blur = {
        enabled = true;
        size = 8;
        passes = 3; # >3 is diminishing returns + FPS hit on 4K.
        new_optimizations = true; # Free perf win, no visual cost.
        vibrancy = 0.1696;
        noise = 0.0117;
        popups = true; # Blur menus/tooltips too — critical for Finder/menubar feel.
        popups_ignorealpha = 0.2;
        ignore_opacity = false;
      };
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
      # behavior (default 0) feels broken on macOS-y workflows.
      # (Renamed from new_window_takes_over_fullscreen in Hyprland 0.50+.)
      on_focus_under_fullscreen = 2;
      # Apps stop yanking focus when they want attention — they get an
      # urgency hint instead. Major quality-of-life win.
      focus_on_activate = false;
      # Solid dark color behind windows. Eliminates the brief flash before
      # hyprpaper loads the wallpaper.
      background_color = lib.mkForce "0xff0a0a0f";
    };

    # macOS-style three-finger swipe between workspaces. Only triggers if a
    # touchpad is present, so safe to define globally.
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
      # Match touchpad natural_scroll direction so swipe-left moves right.
      workspace_swipe_invert = true;
      # Lower = flicks more reliable; 30 (default) is sluggish.
      workspace_swipe_min_speed_to_force = 15;
      # Past halfway commits, otherwise springs back — macOS behavior.
      workspace_swipe_cancel_ratio = 0.5;
      # Apple doesn't conjure new spaces mid-swipe.
      workspace_swipe_create_new = false;
      # Keep swiping past first workspace without snapping.
      workspace_swipe_forever = true;
      workspace_swipe_direction_lock = true;
      # Use real workspace indices so 1->2->3 feels linear (the
      # underrated knob — dispatcher order can be non-monotonic).
      workspace_swipe_use_r = true;
    };

    # Layer rules govern blur for shell-surfaces (waybar, rofi, notifications).
    # `ignore_alpha N` skips blur on pixels with alpha < N — this is what kills
    # the dark halo around panels and is the single biggest panel-blur upgrade.
    # Rules for namespaces that don't exist on this host are no-ops.
    #
    # Hyprland 0.50+ syntax notes:
    #   - `blur` -> `blur on` (the rule needs an explicit value)
    #   - `ignorealpha` -> `ignore_alpha` (underscore)
    #   - bare namespace -> `match:namespace <regex>`
    #   - `ignorezero` was removed; use a small `ignore_alpha` value instead.
    layerrule = [
      "blur on, match:namespace waybar"
      "ignore_alpha 0.2, match:namespace waybar"
      "blur on, match:namespace rofi"
      "ignore_alpha 0.5, match:namespace rofi"
      "blur on, match:namespace wofi"
      "ignore_alpha 0.5, match:namespace wofi"
      "blur on, match:namespace notifications"
      "ignore_alpha 0.3, match:namespace notifications"
      "blur on, match:namespace swaync-control-center"
      "blur on, match:namespace swaync-notification-window"
      "blur on, match:namespace logout_dialog"
    ];

    animations = {
      enabled = true;
      # Bezier curves are `name, x1, y1, x2, y2` — same as CSS cubic-bezier.
      # Y values >1 cause overshoot (animation briefly goes past endpoint).
      bezier = [
        # Gentle overshoot for close/dismiss (the 1.05 at the end).
        "wind, 0.05, 0.9, 0.1, 1.05"
        # Open with overshoot at peak, settles cleanly at endpoint.
        # End Y was 1.1 — implausible (settled past target); 1.05 reads natural.
        "winIn, 0.1, 1.1, 0.1, 1.05"
        # Apple-standard ease-out: fast start, smooth glide to stop.
        # Used everywhere a smooth, non-overshooting curve is needed.
        "easeOutExpo, 0.16, 1, 0.3, 1"
        # Constant velocity — only useful for slow color blends.
        "liner, 1, 1, 1, 1"
      ];
      # Durations are in deciseconds (5 = 0.5s).
      animation = [
        # Window open: overshoot bezier, popin starts at 90% (less zoom than
        # the 87% default — macOS uses ~92–95%).
        "windows, 1, 5, winIn, popin 90%"
        "windowsOut, 1, 4, wind, popin 90%"
        "fadeOut, 1, 3, default"
        "fadeIn, 1, 3, default"
        # The three "feels alive" events — transitions between focus states.
        "fadeSwitch, 1, 3, easeOutExpo"
        "fadeShadow, 1, 5, easeOutExpo"
        "fadeDim, 1, 4, easeOutExpo"
        # Workspace slide: clean ease-out, NO overshoot (overshoot on a
        # full-screen slide reads as broken). 4 deciseconds is Apple-snappy.
        "workspaces, 1, 4, easeOutExpo, slide"
        # Scratchpad drops from top — distinct from regular workspace switch.
        "specialWorkspace, 1, 4, easeOutExpo, slidefadevert -50%"
        # Asymmetric layer animations: IN slow + overshoot (deliberate
        # entrance), OUT faster + simple ease (snappy exit). Polished feel.
        "layersIn, 1, 3, winIn, slide"
        "layersOut, 1, 2, wind, slide"
        "fadeLayersIn, 1, 2, easeOutExpo"
        "fadeLayersOut, 1, 2, easeOutExpo"
        # Slow border color blend on focus change — barely conscious, but felt.
        "border, 1, 10, liner"
      ];
    };
  };
}
