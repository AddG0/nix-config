# Hyprland visual config — macOS-leaning aesthetic.
#
# Design pillars:
#   1. Depth via shadows, not borders. Hairline borders + soft drop shadow
#      communicate focus; thick colored frames fight the rounded corners.
#   2. Frosted-glass blur on panels/menus (Big Sur look). Vibrancy + noise
#      mimic Apple's saturation boost and grain.
#   3. Squircle corners (rounding_power 3.0) — Apple's superellipse, not a
#      plain circular arc.
#   4. Snappy ease-out motion — all curves end at y2=1 (no overshoot, no
#      bounce). macOS-leaning but tightened from Apple's slower defaults
#      because tiling-WM workflows feel sluggish with full Apple timing.
#   5. Symmetric in/out on layers (~0.2s each) so menus/notifications feel
#      responsive both opening and closing.
#
# mkForce calls below override two upstream sources:
#   - settings.nix in ../common sets gaps_in / gaps_out to 5/10
#   - stylix's catppuccin hyprland target auto-themes col.active_border,
#     col.inactive_border, decoration.shadow.color, and background_color
#     from base16 (base0D/base03/base00). We want the soft-white aesthetic,
#     not the auto-themed blue accent, so we force the override.
{
  lib,
  config,
  ...
}: let
  c = config.lib.stylix.colors;
  sans = config.stylix.fonts.sansSerif.name;
  # Stylix-driven desktop text size — same value waybar/notifications use,
  # so the hy3 tab labels match the rest of the system chrome.
  desktopFontSize = config.stylix.fonts.sizes.desktop;
  # Rounded-corner radius — used by window decoration, hy3 tabs, and the
  # noctalia bar frame so they can't drift apart. Also duplicated in
  # walker.nix; keep them in sync.
  windowRounding = 10;
  # Outer gap between windows and screen edge. Reused by the noctalia bar
  # horizontal margin so the bar and window edges align.
  edgeGap = 8;
in {
  wayland.windowManager.hyprland.settings = {
    # NOTE: we used to `source` catppuccin's themes/mocha.conf here, but
    # catppuccin/hyprland migrated to Lua-only themes (no .conf ships
    # anymore), and nothing below references its palette vars — every color
    # is mkForce'd from stylix or a literal rgba. So the source is dropped;
    # stylix's catppuccin hyprland target still drives the base16 colors we
    # then override.

    general = {
      # 1px hairline. macOS uses ~1px; 4px competes with the drop shadow.
      border_size = 1;
      # Tight gaps so shadows are visible without screaming "tiling WM".
      # Overrides settings.nix defaults of 5/10 — hence mkForce.
      gaps_in = lib.mkForce 4;
      gaps_out = lib.mkForce edgeGap;
      # Soft white gradient on focus — still secondary to the shadow, but
      # bumped a touch (60/20 alpha vs prior 40/10) so the active window has
      # a perceptible edge against dark wallpapers.
      "col.active_border" = lib.mkForce "rgba(ffffff60) rgba(ffffff20) 45deg";
      "col.inactive_border" = lib.mkForce "rgba(00000020)";
    };

    decoration = {
      # 10 = tightest reasonable macOS-ish rounding. Tahoe (26) bumped the
      # system default to 16, but 16 visually clipped corner items in the
      # walker launcher list. 12 was the Sequoia-leaning compromise; 10
      # goes a touch further for usability (bigger corners shrink the
      # resize hot-zone) while still reading as Apple-ish.
      rounding = windowRounding;
      # Squircle exponent (Hyprland >=0.45). 2.0 = circular arc; 3.0 = Apple
      # superellipse — corners look slightly "fatter" near the midpoint.
      rounding_power = 3.0;
      # Kept close to opaque — a hint of glass for depth, but the 0.9/0.8
      # pairing read as too transparent once the full decoration block
      # applied on the hyprlang backend. The blur below carries most of the
      # frosted look, so the windows themselves don't need much see-through.
      active_opacity = 0.97;
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
        color_inactive = "rgba(00000028)"; # Lighter — subtle focus cue.
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

    # hy3 tab-group styling (Super+G toggles a tabbed group). Follows the
    # same pillars as the window decoration above:
    #   - Pill shape (radius = height/2) — Safari-style; reads as a control,
    #     not a panel.
    #   - Hairline 1px borders matching general.border_size = 1 — anything
    #     thicker fights the rounded shape (pillar #1).
    #   - Soft white tints for active/focused; urgent keeps base08 because
    #     urgency must read at a glance (the one exception).
    #
    # Color-key syntax is version-dependent. For hy3 ≤ 0.54.x (current),
    # the canonical keys are flat dotted at the tabs level:
    #   col.active        col.active.border        col.active.text
    # Master branch moved them under a `colors { ... }` subsection with
    # snake_case names — that syntax is silently ignored on 0.54.x. If you
    # bump hy3 past the rename, swap the keys back to `colors.*`. Verify
    # with `hyprctl getoption plugin:hy3:tabs:col.active.border` — `set:
    # true` means it bound.
    plugin.hy3.tabs = {
      # 32px tab strip matches macOS Safari proportions. radius reuses
      # windowRounding so the tab corners and window corners can't drift
      # apart — single knob controls both.
      height = 32;
      padding = 6;
      radius = windowRounding;
      border_width = 1;
      render_text = true;
      text_center = true;
      # Pango font description — appending the weight bumps the label from
      # Regular (400) to Medium (500). Thin weights smear against blurred
      # backdrops at small sizes; Medium is what Safari uses for tab labels.
      text_font = "${sans} Medium";
      # Drive text size from stylix so tab labels track the same scale as
      # waybar, notifications, and every other desktop chrome surface.
      text_height = desktopFontSize;
      # text_padding is left-padding only (no-op with text_center = true).

      # Slide in from above the window — matches the `layersIn` slide and
      # reads as a macOS-style dropdown header instead of popping up from
      # below the content.
      from_top = true;

      blur = true;
      opacity = 0.96;

      # Active: bright white pill, hairline white edge — focus reads via
      # contrast against the blurred backdrop, not via a saturated frame.
      # Fill bumped from 30 → 40 alpha so the active pill pops more clearly
      # against the darker inactive substrate.
      "col.active" = "rgba(ffffff40)";
      "col.active.border" = "rgba(ffffff70)";
      "col.active.text" = "rgba(ffffffff)";

      # Same tab on a non-focused monitor — one step dimmer. Default is a
      # harsh grey that breaks the macOS feel on multi-monitor.
      "col.active_alt_monitor" = "rgba(ffffff1c)";
      "col.active_alt_monitor.border" = "rgba(ffffff35)";
      "col.active_alt_monitor.text" = "rgba(${c.base05}ee)";

      # Focused (group focused, tab not active) — between active and
      # inactive in weight.
      "col.focused" = "rgba(ffffff1c)";
      "col.focused.border" = "rgba(ffffff35)";
      "col.focused.text" = "rgba(${c.base05}ee)";

      # Inactive uses a dark substrate so lightened base05 text reads
      # against a busy wallpaper through the blur.
      "col.inactive" = "rgba(00000066)";
      "col.inactive.border" = "rgba(00000028)";
      "col.inactive.text" = "rgba(${c.base05}bb)";

      "col.urgent" = "rgba(${c.base08}80)";
      "col.urgent.border" = "rgba(${c.base08}dd)";
      "col.urgent.text" = "rgba(ffffffff)";

      # Locked (hy3:locktab pin) — base0A yellow keeps the "pinned"
      # signal without the urgency-red scream.
      "col.locked" = "rgba(${c.base0A}40)";
      "col.locked.border" = "rgba(${c.base0A}aa)";
      "col.locked.text" = "rgba(${c.base05}ee)";
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
      # wpaperd loads the wallpaper. Tracks stylix base00 so it stays in
      # sync with theme changes — stylix's catppuccin target also sets this
      # to rgb(base00), but home-manager flags any redefinition as a
      # conflict, so we mkForce.
      background_color = lib.mkForce "0xff${c.base00}";
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
      # Assumes natural-scroll touchpads (the macOS default). If a host
      # disables natural scroll system-wide, swipes will feel inverted —
      # override per-host in that case.
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

    # Window rules — visual treatment for specific app classes.
    #
    # Ghostty (primary terminal) gets explicit 96/88% opacity so the desktop
    # bleeds through enough to feel "alive". Tighter range than the typical
    # Linux 90/80 — text readability matters more than transparency theatre.
    # The `override` flag stops Hyprland from multiplying the rule by the
    # global active/inactive_opacity (1.0/0.9), which would have left inactive
    # ghostty at 0.79 — too dim to scan against other terminals.
    #
    # Only ghostty is styled because it's the primary terminal here; other
    # terminals listed in `enable_swallow` fall back to the global opacity
    # (which is intentionally less aggressive).
    #
    # Note: Hyprland's `dim_around` effect is layer-only, not a windowrule;
    # polkit/auth prompts can't get a macOS-modal dim through windowrules.
    # The closest equivalents would be `decoration.dim_inactive = true` (dims
    # everything unfocused, globally) or a polkit theme that draws its own
    # dim overlay.
    windowrule = [
      "opacity 0.96 0.88 override, match:class ^(com\\.mitchellh\\.ghostty|ghostty)$"
      # Zen and VLC stay fully opaque in every state — active, inactive, and
      # fullscreen. `override` wins over the global active/inactive_opacity
      # (1.0/0.9) so neither dims when unfocused. (Hover-focus = the active
      # state, so this already covers "on hover".)
      "opacity 1.0 override 1.0 override 1.0 override, match:class ^(zen|zen-alpha|zen-beta)$"
      "opacity 1.0 override 1.0 override 1.0 override, match:class ^(vlc)$"
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
      ];
      # Durations in deciseconds (3 = 0.3s). Roughly half of the previous
      # "macOS deliberate" timings — feels fast and responsive without
      # losing the ease-out polish.
      animation = [
        # Window open: snappy with minimal zoom (92% start = barely scales).
        "windows, 1, 3, snappy, popin 92%"
        "windowsOut, 1, 2, snappy, popin 92%"
        "fadeOut, 1, 2, snappy"
        "fadeIn, 1, 2, snappy"
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

  # Noctalia styling — personal shape/layout only. Colors, fonts, and opacity
  # are stylix-derived and live in ./stylix-noctalia-compat.nix.
  programs.noctalia.settings = {
    # macOS-style drop shadow — straight down, never horizontal offset.
    shell.shadow.direction = "down";

    bar.main = {
      margin_ends = edgeGap; # Align bar ends with window outer gap.
      margin_edge = edgeGap; # Match so top spacing equals the sides.
      radius = windowRounding; # Same source of truth as windows + tabs.
      capsule = true; # Pill-shaped widget backgrounds (Control Center vibe)
      border_width = 0; # Shadow + transparency do the framing, not a border.
      widget_spacing = 6;
      padding = 4;
      shadow = true;
    };
  };

  # Hyprlock styling lives in ./hyprlock.nix.
}
