# Hyprlock — Material Design 3 lock screen. Colors are set here rather than
# left to stylix's hyprlock target, which can't reach the roles the layout
# needs (primary while checking, error on a failed attempt).
#
# The wallpaper blur below is the only blur left in the desktop — Android blurs
# the wallpaper behind the lock, so it stays. Surfaces are still opaque.
#
# OLED gating: if any monitor on this host is OLED, the full rich lock is
# swapped for a minimal one — just the pill input field with fade-on-empty.
# A static clock/date/avatar at the same screen position every lock event
# accumulates localized wear on OLED panels (~5-10 min per lock × many
# locks/day). The minimal version keeps the screen pure black until the
# user starts typing, mirroring iPhone/iPad OLED unlock behavior.
#
# The base `programs.hyprlock.enable = true` and the SUPER+escape bind live in
# ../common/hyprlock.nix. This file only adds styling.
{
  lib,
  config,
  ...
}: let
  c = config.lib.stylix.colors;
  # Catppuccin's containers are surface0/1 (base02/03) — base01 is darker than
  # base00. base04 is 2.46:1 as text, hence the muted tone instead.
  surfaceContainer = c.base02;
  surfaceContainerHigh = c.base03;
  outline = c.base04;
  onSurfaceVariant = lib.removePrefix "#" config.lib.palette.muted.text;
  sans = config.stylix.fonts.sansSerif.name;
  hostHasOled = lib.any (m: m.oled) config.display.monitors;
  enabledMonitors = lib.filter (m: m.enabled) config.display.monitors;

  # Default: blurred screenshot of the last frame. Any module that needs
  # to override a specific output's lock background writes into
  # `programs.hyprlock.backgroundOverrides` (declared in ../common/hyprlock.nix)
  # — that hook keeps this file agnostic about who's overriding what.
  overrides = config.programs.hyprlock.backgroundOverrides;

  defaultBg = m: {
    monitor = m.output;
    path = "screenshot";
    blur_passes = 4;
    blur_size = 8;
    brightness = 0.6;
    contrast = 0.85;
    vibrancy = 0.25;
    vibrancy_darkness = 0.0;
  };

  # Overrides REPLACE the default block (rather than merging) — leaking
  # `path = screenshot` next to `color = ...` would either confuse
  # hyprlock or render both. `{ monitor = ...; } //` makes sure the
  # override doesn't need to repeat the monitor name.
  bgForMonitor = m:
    if overrides ? ${m.output}
    then {monitor = m.output;} // overrides.${m.output}
    else defaultBg m;
in {
  programs.hyprlock.settings = {
    general = {
      ignore_empty_input = true; # Don't show fail state on bare Enter
      immediate_render = true; # No flash of unstyled lock at start
      hide_cursor = true; # Reveal on movement only
    };

    # Hyprlock animation system (v0.7.0+); `inputFieldColors` supersedes the old
    # `fail_transition`. The slow `fadeIn` is what keeps the lock from popping
    # in; deliberately left at 500ms when the desktop dropped to 200.
    animations = {
      enabled = true;
      bezier = [
        "emphasized, 0.2, 0, 0, 1"
        "emphasizedDecelerate, 0.05, 0.7, 0.1, 1"
      ];
      animation = [
        "fadeIn, 1, 5, emphasizedDecelerate"
        "fadeOut, 1, 6, emphasizedDecelerate"
        "inputFieldColors, 1, 2, emphasized"
        "inputFieldFade, 1, 4, emphasizedDecelerate"
        "inputFieldWidth, 1, 4, emphasizedDecelerate"
        "inputFieldDots, 1, 2, emphasized"
      ];
    };

    # Fingerprint auth in parallel with password (hyprlock PR #514).
    # Requires fprintd at the system level; if not configured/no reader,
    # this is a silent no-op.
    auth.fingerprint = {
      enabled = true;
      ready_message = "Scan finger";
      present_message = "Scanning…";
    };

    # Per-monitor backgrounds — see bgForMonitor above. mkForce overrides
    # stylix's hyprlock target, which sets a single-attrset background.
    # Fallback (no declared monitors) keeps the screenshot-blur behavior.
    background = lib.mkForce (
      if enabledMonitors == []
      then [
        {
          path = "screenshot";
          blur_passes = 4;
          blur_size = 8;
          brightness = 0.6;
          contrast = 0.85;
          vibrancy = 0.25;
          vibrancy_darkness = 0.0;
        }
      ]
      else map bgForMonitor enabledMonitors
    );

    # Card behind the avatar / greeting / input stack, shaped as an M3 dialog.
    # zindex -1 keeps it behind labels & inputs.
    shape = lib.mkIf (!hostHasOled) [
      {
        size = "380, 300";
        color = "rgba(${surfaceContainer}ff)";
        rounding = 28;
        border_size = 0;
        position = "0, -150";
        halign = "center";
        valign = "center";
        zindex = -1;
      }
    ];

    label = lib.mkIf (!hostHasOled) (
      [
        # Light at 140px carries the same visual mass as a regular face at
        # half the size.
        {
          text = ''cmd[update:1000] date +"%I:%M"'';
          color = "rgba(${c.base05}ff)";
          font_size = 140;
          font_family = "${sans} Light";
          position = "0, 220";
          halign = "center";
          valign = "center";
          # Subtle lift, not glow — shadow_boost > 1.2 reads gamer.
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(0000004d)";
          shadow_boost = 1.0;
        }
        # Medium weight for hierarchy against the light clock above.
        {
          text = ''cmd[update:60000] date +"%A, %B %-d"'';
          color = "rgba(${onSurfaceVariant}ff)";
          font_size = 24;
          font_family = "${sans} Medium";
          position = "0, 110";
          halign = "center";
          valign = "center";
        }
        {
          text = "Hi, $USER";
          color = "rgba(${c.base05}ff)";
          font_size = 16;
          font_family = "${sans}";
          position = "0, -150";
          halign = "center";
          valign = "center";
        }
        # Fingerprint prompt — only shows text when fprintd is active.
        {
          text = "$FPRINTPROMPT";
          color = "rgba(${onSurfaceVariant}ff)";
          font_size = 12;
          font_family = "${sans}";
          position = "0, -310";
          halign = "center";
          valign = "center";
        }
      ]
      # Battery indicator, bottom-right (laptop only). Reads BAT* so any
      # battery naming works. 30s refresh — lock screen, not a meter.
      ++ lib.optionals (config.hostSpec.hostType == "laptop") [
        {
          text = ''cmd[update:30000] echo "  $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)%"'';
          color = "rgba(${onSurfaceVariant}ff)";
          font_size = 14;
          font_family = "${sans}";
          position = "-24, 24";
          halign = "right";
          valign = "bottom";
        }
      ]
    );

    # User avatar — round circle above the greeting.
    image = lib.mkIf (!hostHasOled) [
      {
        path = "/var/lib/AccountsService/icons/${config.home.username}";
        size = 96;
        rounding = -1; # -1 = perfect circle
        position = "0, -80";
        halign = "center";
        valign = "center";
        shadow_passes = 2;
        shadow_size = 5;
        shadow_color = "rgba(0000004d)";
      }
    ];

    # Password input — pill-shaped, centered. On OLED hosts we strip the
    # placeholder text and turn on fade_on_empty so the screen returns to
    # pure black when the user stops typing — only lit pixels are the
    # password dots while actively entering. On LCD we keep the richer
    # variant with persistent placeholder text.
    input-field = lib.mkForce [
      ({
          size = "320, 52";
          outline_thickness = 1;
          dots_size = 0.22;
          dots_spacing = 0.4;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "rgba(${outline}ff)"; # M3 outline
          inner_color = "rgba(${surfaceContainerHigh}ff)";
          font_color = "rgba(${c.base05}ff)";
          font_family = "${sans}";
          check_color = "rgba(${c.base0D}ff)"; # primary, while checking
          fail_color = "rgba(${c.base08}ff)"; # error
          fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
          capslock_color = "rgba(${c.base0A}ff)"; # tertiary
          rounding = 26; # Half of height — M3 full shape, like a search bar
          shadow_passes = 1;
          shadow_size = 4;
          shadow_color = "rgba(0000004d)";
          halign = "center";
          valign = "center";
        }
        // (
          if hostHasOled
          then {
            position = "0, 0"; # Centered — no labels above/below to anchor to
            fade_on_empty = true;
            fade_timeout = 2000;
            placeholder_text = "";
          }
          else {
            position = "0, -240";
            fade_on_empty = false;
            placeholder_text = "<i>Enter password</i>";
          }
        ))
    ];
  };
}
