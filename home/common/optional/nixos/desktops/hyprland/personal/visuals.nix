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
      # Soft white gradient on focus — still secondary to the shadow, but
      # bumped a touch (60/20 alpha vs prior 40/10) so the active window has
      # a perceptible edge against dark wallpapers.
      "col.active_border" = lib.mkForce "rgba(ffffff60) rgba(ffffff20) 45deg";
      "col.inactive_border" = lib.mkForce "rgba(00000020)";
    };

    decoration = {
      # macOS Tahoe (26) uses 16px on plain windows, up to ~24px on windows
      # with toolbars. 12 was Sequoia-leaning; 16 matches the current Apple
      # default. (Some devs push back to 10 for usability — bigger corners
      # shrink the resize hot-zone.)
      rounding = 16;
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

      # Dim everything behind the special workspace when it's active. Gives
      # special-workspace apps (Spotify scratchpad, AWS VPN, etc.) a modal /
      # macOS Notification Center feel instead of just floating windows.
      dim_special = 0.4;

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

    # Window rules — visual treatment for specific app classes.    # Subtle frosted terminal: ghostty drops to 96/88% opacity so the
    # desktop bleeds through just enough to feel "alive". Tighter range
    # than the typical Linux 90/80 — text readability matters more than
    # transparency theatre.
    #
    # Note: Hyprland's `dim_around` effect is layer-only, not a windowrule;
    # polkit/auth prompts can't get a macOS-modal dim through windowrules.
    # The closest equivalents would be `decoration.dim_inactive = true` (dims
    # everything unfocused, globally) or a polkit theme that draws its own
    # dim overlay.
    windowrule = [
      "opacity 0.96 0.88, match:class ^(com\\.mitchellh\\.ghostty|ghostty)$"
    ];

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
      # All curves keep Y values within [0,1] so nothing overshoots. macOS
      # uses smooth ease-out curves throughout — no springy/bouncy motion.
      bezier = [
        # Snappy ease-out — sharper than easeOutExpo, less time hanging at
        # the end. Used for window/workspace/layer motion.
        "snappy, 0.25, 0.8, 0.25, 1"
        # Apple-standard ease-out for cases where snappy is too aggressive
        # (fades, scratchpad, color blends).
        "easeOutExpo, 0.16, 1, 0.3, 1"
        # Constant velocity — only for slow color blends.
        "liner, 1, 1, 1, 1"
      ];
      # Durations in deciseconds (3 = 0.3s). Roughly half of the previous
      # "macOS deliberate" timings — feels fast and responsive without
      # losing the ease-out polish.
      animation = [
        # Window open: snappy with minimal zoom (92% start = barely scales).
        "windows, 1, 3, snappy, popin 92%"
        "windowsOut, 1, 2, snappy, popin 92%"
        "fadeOut, 1, 2, default"
        "fadeIn, 1, 2, default"
        # Focus-transition events.
        "fadeSwitch, 1, 2, easeOutExpo"
        "fadeShadow, 1, 3, easeOutExpo"
        "fadeDim, 1, 2, easeOutExpo"
        # Workspace transition: tighter slide (20%), snappy curve.
        "workspaces, 1, 3, snappy, slidefade 20%"
        # Scratchpad still gets the deliberate full slide-from-top, but
        # quicker than before. Distinct feel from regular workspace switches.
        "specialWorkspace, 1, 4, easeOutExpo, slidefadevert -100%"
        # Layers (menus, notifications) — symmetric snappy in/out.
        "layersIn, 1, 2, snappy, slide"
        "layersOut, 1, 2, snappy, slide"
        "fadeLayersIn, 1, 1, easeOutExpo"
        "fadeLayersOut, 1, 1, easeOutExpo"
        # Border color blend — was 10 (liner, very slow); 5 with ease-out
        # reads as deliberate without being sluggish.
        "border, 1, 5, easeOutExpo"
      ];
    };
  };

  # Noctalia (Quickshell bar) — styling-only settings live here so all the
  # personal-flavor visual choices are in one file. Functional config
  # (widgets, exec-once, locate-city script, settings version, preferences
  # like nightLight/location) stays in noctalia.nix.
  # Noctalia styling — only the fields stylix doesn't already drive. Stylix
  # flows colors, fonts, and opacity.{desktop,popups} into the bar/dock/OSD/
  # notifications via its noctalia target module, so we don't set those here.
  # What's left is shape/layout (floating bar, margins, rounding) and shadow
  # direction.
  programs.noctalia-shell.settings = {
    bar = {
      # Floating bar — required for margin/frameRadius/outerCorners to take
      # effect. "simple" mode is edge-to-edge and ignores them.
      marginVertical = 6;
      marginHorizontal = 8;
      frameRadius = 16; # Matches decoration.rounding above
      outerCorners = true;
      showCapsule = true; # Pill-shaped widget backgrounds (Control Center vibe)
      showOutline = false; # Shadow + transparency do the framing
      widgetSpacing = 6;
      contentPadding = 4;
    };
    general = {
      # macOS-style drop shadow — straight down, never horizontal offset.
      # Pairs with the Hyprland window shadow (offset "0 8") above.
      shadowDirection = "bottom";
      shadowOffsetX = 0;
      shadowOffsetY = 4;
      enableShadows = true;
      enableBlurBehind = true; # Frosted glass behind the bar
    };
  };

  # Hyprlock styling lives in ./hyprlock.nix.
}
