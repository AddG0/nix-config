# Walker — Wayland GTK4 launcher. Replaces anyrun (slow upstream, brittle
# plugin API). Walker's daemon model + provider system is the closest match
# to anyrun's shape, and the GTK4 CSS port from anyrun.nix is direct.
#
# Layout intent: same as the rest of the desktop — frosted base00 panel,
# hairline alpha-fg border, soft drop shadow, soft-fg selection. Tokens
# (windowRounding = 10) are duplicated from visuals.nix intentionally;
# see prior conversation about not factoring out a shared design-tokens
# module for a single-WM setup.
{
  inputs,
  config,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  sans = config.stylix.fonts.sansSerif.name;
  # Duplicated from visuals.nix — keep in sync.
  windowRounding = 10;
in {
  imports = [inputs.walker.homeManagerModules.default];

  programs.walker = {
    enable = true;
    # HM module manages a systemd --user service for the daemon, so first
    # keystroke is instant. Replaces the hand-rolled anyrun-daemon unit.
    runAsService = true;

    config = {
      theme = "macos";

      # Layer-shell mode (default); leave `as_window = false` so the
      # launcher floats above other surfaces with no window-decoration.
      close_when_open = true;
      click_to_close = true;
      single_click_activation = true;
      force_keyboard_focus = true;
      selection_wrap = false;
      # Show the bottom action-hint row — Walker populates it with the
      # keybinds for the currently selected item (↵ open, ⌘↵ open-new,
      # etc.). Custom .keybinds CSS rule below tames the default jarring
      # accent chips into subtle base-fg labels.
      hide_action_hints = false;

      placeholders."default" = {
        input = "Search…";
        list = "No results";
      };

      providers = {
        # Apps + math (rink-equivalent) + websearch — mirrors the anyrun
        # plugin set. `files` is opt-in via the "/" prefix to avoid noisy
        # filesystem hits on every keystroke.
        default = ["desktopapplications" "calc" "websearch"];
        empty = ["desktopapplications"];
        max_results = 5; # Same density as anyrun (maxEntries = 5).

        prefixes = [
          # Match anyrun's "?" websearch prefix so muscle memory carries.
          {
            provider = "websearch";
            prefix = "?";
          }
          {
            provider = "files";
            prefix = "/";
          }
          {
            provider = "calc";
            prefix = "=";
          }
        ];
      };

      keybinds = {
        close = ["Escape"];
        # F1-F4 quick-activate the first 4 results without arrow-keying.
        quick_activate = ["F1" "F2" "F3" "F4"];
      };
    };

    themes.macos = {
      # Walker GTK4 stylesheet. Selectors verified against walker's default
      # theme — the `* { all: unset; }` reset is REQUIRED, without it GTK
      # default styling (focus rings, entry borders, button chrome) leaks
      # through and overrides everything below. Debug with
      # `GTK_DEBUG=interactive walker` if a rule misses.
      style = ''
        /* Kill GTK defaults so our rules are the only source of truth. */
        * {
          all: unset;
          font-family: "${sans}";
        }

        @define-color bg ${c.base00};
        @define-color bg_alt ${c.base01};
        @define-color border ${c.base02};
        @define-color fg ${c.base05};
        @define-color fg_dim ${c.base04};
        @define-color fg_subtle ${c.base03};
        @define-color sel ${c.base02};

        /* Outer layer-shell window — transparent so only .box-wrapper draws. */
        window {
          background-color: transparent;
        }

        /* The launcher panel itself. Semi-transparent so the layerrule
           blur (in visuals.nix peer config) actually shows through —
           solid bg = nothing to frost. Border uses stylix foreground at
           low alpha = Apple inner-edge highlight that tracks the active
           scheme (warmer fg → warmer edge).
           Subtle vertical gradient (top slightly lighter) is the Apple
           panel trick — makes the surface read as physically lit from
           above rather than uniformly tinted. */
        .box-wrapper {
          background-image: linear-gradient(
            to bottom,
            alpha(@fg, 0.04),
            alpha(@bg, 0)
          );
          background-color: alpha(@bg, 0.72);
          border: 1px solid alpha(@fg, 0.14);
          border-radius: ${toString windowRounding}px;
          padding: 8px;
          margin: 24px; /* breathing room for shadow to render */
          /* Shadow stays raw rgba(0,0,0,…) — shadows darken rather than
             tint, so deriving from stylix would be wrong here.
             Previous version (24px offset, 60px blur, 0.65 opacity) read
             as a dark "bar" below the panel because the shadow density
             was concentrated downward. This is tuned tighter:
             - Close ambient (2px/6px/0.15) grounds the panel
             - Soft halo (8px/32px/0.22) surrounds it without bleeding
               aggressively downward — lower offset = more even surround
             - Inset top-edge gleam is the Apple "lit-from-above" cue
             Apple's macOS popover shadows use this same close+soft
             pairing with low opacities. */
          box-shadow:
            0 3px 10px 0 rgba(0, 0, 0, 0.3),
            0 12px 40px 0 rgba(0, 0, 0, 0.5),
            inset 0 1px 0 0 alpha(@fg, 0.08);
          min-width: 640px;
        }

        /* Search input — large Spotlight-scale font. No background fill
           (would compete with the frosted panel); the separator below is
           what distinguishes the input from the result list. Generous
           padding gives the launcher a "breathy" Apple feel. */
        .input {
          background-color: transparent;
          color: @fg;
          caret-color: @fg;
          padding: 14px 16px 16px 16px;
          font-size: 1.35em;
          font-weight: 400;
        }

        /* Placeholder slightly more dim than default 0.5 — keeps the
           focus on actual typed text. */
        .input placeholder {
          opacity: 0.4;
        }

        /* List container — hairline separator above so the input reads as
           a distinct surface. Same alpha-fg pattern as the panel border. */
        .list {
          background-color: transparent;
          padding: 8px 0 0 0;
          border-top: 1px solid alpha(@fg, 0.08);
        }

        /* Each result row — more vertical breathing room than the default
           tight 8/10. Spotlight rows feel tall and luxurious. */
        .item-box {
          padding: 10px 12px;
          border-radius: 8px;
        }

        /* Hover state — subtle pre-selection cue. Half the alpha of
           the selection so it doesn't compete with keyboard nav. */
        child:hover .item-box,
        row:hover .item-box {
          background-color: alpha(@fg, 0.05);
        }

        /* Selection — soft translucent highlight (Spotlight style), not
           a solid base02 block. alpha(@fg) reads through the frosted
           panel as a gentle gleam. */
        child:selected .item-box,
        row:selected .item-box {
          background-color: alpha(@fg, 0.12);
        }

        /* Icon — authoritative selector per walker's layout XML
           (icon-size: large in the XML maps to 32px). Setting it
           explicitly here removes ambiguity if walker ever ships a
           layout change. */
        .item-image {
          -gtk-icon-size: 32px;
          min-width: 32px;
          min-height: 32px;
        }

        /* Primary label (app name). Medium weight — Spotlight uses
           SF Pro Medium for results; in our stack Inter Medium fills the
           same role and reads better against frosted glass than Regular. */
        .item-text {
          color: @fg;
          font-size: 1em;
          font-weight: 500;
        }

        /* Secondary label (description / generic-name). Smaller + dim so
           the eye picks the primary label first; 2px top margin breathes
           against the primary label (walker's item.xml uses spacing=0).
           Most providers don't populate subtext in walker, but when they
           do (calc result preview, file path under match, etc.) the
           styling here applies. */
        .item-subtext {
          color: @fg_dim;
          font-size: 0.85em;
          margin-top: 2px;
        }

        /* Bottom keybind hint row.
           Walker structures this as a horizontal box of .keybind chips,
           each of which is a vertical stack:
             .keybind-button > .keybind-label  (action name, e.g. "open")
             .keybind-bind                     (key combo, e.g. "↵")
           The default GtkButton chrome on .keybind-button is what made
           the old action-hints row look jarring; we flatten it to a
           plain text label so the chip reads as a typography hint, not
           a clickable control. */
        .keybinds {
          padding: 10px 4px 2px 4px;
          border-top: 1px solid alpha(@fg, 0.08);
        }

        /* Spacing between hint columns. */
        .keybind {
          padding: 0 14px;
        }

        /* Flatten the GtkButton — no bg, no border, no focus ring,
           no padding contribution. The `* { all: unset; }` reset at
           the top sets this most of the way but GtkButton's own node
           defaults can sneak back in via specificity. */
        .keybind-button {
          background: transparent;
          border: none;
          box-shadow: none;
          padding: 0;
          min-height: 0;
        }

        /* Action name (top line of each chip). */
        .keybind-label {
          color: @fg_dim;
          font-size: 0.8em;
        }

        /* Key combo glyph (bottom line). Slightly dimmer + tabular nums
           so glyphs like ↵/↑/↓ sit on their own visual baseline and
           ⌘+digit combinations don't shift width per digit. */
        .keybind-bind {
          color: @fg_subtle;
          font-size: 0.78em;
          font-feature-settings: "tnum";
        }

        /* Per-row quick-activation chip (F1/F2/F3/F4). Default theme
           gave these a saturated accent bg that fights the frosted look;
           drop to a hairline pill that reads as a keyboard hint, not a
           UI control.
           tabular-nums + min-width keep F1/F2/F3/F4 visually identical —
           Inter renders `1` narrower than other digits at proportional
           spacing, which made F1 shift right vs F2-F4. tnum forces
           equal-width digits; min-width is the safety net for fonts
           that don't honour font-feature-settings. */
        .item-quick-activation {
          background-color: alpha(@fg, 0.08);
          color: @fg_dim;
          border-radius: 5px;
          padding: 2px 8px;
          font-size: 0.8em;
          font-feature-settings: "tnum";
          min-width: 18px;
        }

        /* "No Results" empty-state label. Default would render at full
           foreground — way too loud for a "nothing found" message. */
        .placeholder {
          color: @fg_subtle;
          font-size: 1.1em;
          padding: 24px;
        }

        /* Scrollbar is set to opacity:0 in walker default theme — keep
           that, but explicitly override here so any GTK4 default reset
           doesn't bring it back. The frosted panel reads cleaner
           without a visible scroll track. */
        scrollbar {
          opacity: 0;
        }
      '';
    };
  };

  wayland.windowManager.hyprland.settings = {
    # SUPER+space — same bind anyrun owned.
    bind = ["SUPER,space,exec,walker"];
  };

  # Match the rofi/wofi blur rules in visuals.nix so the launcher gets the
  # same frosted-glass treatment as other layer-shell popups.
  #
  # `animation popin 88%` overrides the global `layersIn` slide for walker
  # so the launcher scales up from 88% rather than sliding from an edge —
  # Spotlight/Raycast feel. 88% sits between the subtle 92% used for
  # windows (visuals.nix) and the more dramatic 80% favored by Raycast.
  # Timing/curve still inherit from the global snappy layersIn rule
  # (per-layer timing override isn't supported by Hyprland; only style).
  wayland.windowManager.hyprland.settings.layerrule = [
    "blur on, match:namespace walker"
    "ignore_alpha 0.5, match:namespace walker"
    "animation popin 88%, match:namespace walker"
  ];

  # Bundled into SUPER+SHIFT+R via the reload pipeline in binds.nix.
  wayland.windowManager.hyprland.reload.commands.elephant = "systemctl --user try-restart elephant.service";
}
