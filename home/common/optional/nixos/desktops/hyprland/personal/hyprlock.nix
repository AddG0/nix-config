# Hyprlock — macOS-leaning lock screen. Stylix doesn't ship a hyprlock target
# so colors/fonts are explicit here. Catppuccin Mocha foreground over a
# heavily-blurred screenshot of what was last on screen.
#
# Layout (top to bottom): big time, smaller date, frosted-glass card holding
# the user avatar (circle), greeting, and pill-shaped password input. Matches
# the macOS Sequoia/Tahoe lock-screen vertical stack.
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
  hostHasOled = lib.any (m: m.oled) config.display.monitors;
in {
  programs.hyprlock.settings = {
    general = {
      grace = 2; # 2-second window to dismiss without auth after lock fires
      ignore_empty_input = true; # Don't show fail state on bare Enter
      immediate_render = true; # No flash of unstyled lock at start
      hide_cursor = true; # Apple hides the cursor until movement
    };

    # Hyprlock animation system (v0.7.0+). Replaces the old `fail_transition`/
    # `fade_on_empty` flags with proper bezier-driven transitions. The slow
    # `fadeIn` is the single biggest "feels Apple" upgrade — lock fades up
    # instead of popping in.
    animations = {
      enabled = true;
      bezier = [
        "easeOutQuint, 0.22, 1, 0.36, 1"
        "snappy, 0.25, 0.8, 0.25, 1"
      ];
      animation = [
        "fadeIn, 1, 4, easeOutQuint"
        "fadeOut, 1, 6, easeOutQuint"
        "inputFieldColors, 1, 2, snappy"
        "inputFieldFade, 1, 4, easeOutQuint"
        "inputFieldWidth, 1, 4, easeOutQuint"
        "inputFieldDots, 1, 2, snappy"
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

    # Note: background is intentionally NOT set here. The oled-protection
    # module forces a solid black background on hyprlock to prevent burn-in
    # from a static blurred screenshot lingering on the lock screen.

    # Frosted-glass card behind the avatar / greeting / input stack — the
    # Tahoe "liquid glass" cue. Reintroduces the depth that aggressive
    # background blur flattens. zindex -1 keeps it behind labels & inputs.
    shape = lib.mkIf (!hostHasOled) [
      {
        size = "380, 300";
        color = "rgba(14141c59)"; # Catppuccin base @ ~35% alpha
        rounding = 28;
        border_size = 1;
        border_color = "rgba(ffffff14)"; # Hairline matching window borders
        position = "0, -150";
        halign = "center";
        valign = "center";
        zindex = -1;
      }
    ];

    label = lib.mkIf (!hostHasOled) (
      [
        # Big time, top-center. Inter Thin at 140px mimics the iconic macOS
        # Tahoe ultra-light clock face. Thin weights need more size to read
        # at the same visual weight as a regular face.
        {
          text = ''cmd[update:1000] date +"%I:%M"'';
          color = "rgba(cdd6f4ee)"; # Catppuccin text
          font_size = 140;
          font_family = "Inter Thin";
          position = "0, 220";
          halign = "center";
          valign = "center";
          # Subtle lift, not glow — shadow_boost > 1.2 reads gamer.
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(00000059)";
          shadow_boost = 1.0;
        }
        # Date — Medium weight provides hierarchy contrast against the thin
        # time. Slightly bigger than before (24 vs 22) to balance the bigger
        # clock above.
        {
          text = ''cmd[update:60000] date +"%A, %B %-d"'';
          color = "rgba(cdd6f4cc)";
          font_size = 24;
          font_family = "Inter Medium";
          position = "0, 110";
          halign = "center";
          valign = "center";
        }
        # Greeting just above the input. Regular weight, slight size bump
        # (17 vs 16) — matches macOS's subtle but legible username line.
        {
          text = "Hi, $USER";
          color = "rgba(cdd6f4ee)";
          font_size = 17;
          font_family = "Inter";
          position = "0, -150";
          halign = "center";
          valign = "center";
        }
        # Fingerprint prompt — only shows text when fprintd is active.
        {
          text = "$FPRINTPROMPT";
          color = "rgba(cdd6f4aa)";
          font_size = 12;
          font_family = "Inter";
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
          color = "rgba(cdd6f4cc)";
          font_size = 14;
          font_family = "Inter";
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
        shadow_color = "rgba(00000060)";
      }
    ];

    # Password input — pill-shaped, centered. On OLED hosts we strip the
    # placeholder text and turn on fade_on_empty so the screen returns to
    # pure black when the user stops typing — only lit pixels are the
    # password dots while actively entering. On LCD we keep the richer
    # variant with persistent placeholder text matching macOS.
    input-field = lib.mkForce [
      ({
          size = "320, 52";
          outline_thickness = 1;
          dots_size = 0.22;
          dots_spacing = 0.4;
          dots_center = true;
          dots_rounding = -1;
          outer_color = "rgba(ffffff20)"; # Hairline border, matches windows
          inner_color = "rgba(00000060)"; # Translucent dark fill
          font_color = "rgba(cdd6f4ee)";
          font_family = "Inter";
          check_color = "rgba(89b4faff)"; # Catppuccin blue while checking
          fail_color = "rgba(f38ba8ee)"; # Catppuccin red on fail
          fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
          fail_transition = 300;
          capslock_color = "rgba(fab387ee)"; # Catppuccin peach
          rounding = 26; # Half of height — full pill
          shadow_passes = 1;
          shadow_size = 4;
          shadow_color = "rgba(00000050)";
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
