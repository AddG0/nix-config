# Walker — Wayland GTK4 launcher. Replaces anyrun (slow upstream, brittle
# plugin API). Walker's daemon model + provider system is the closest match
# to anyrun's shape, and the GTK4 CSS port from anyrun.nix is direct.
#
# Layout intent: an M3 search view — opaque surface-container, elevation-3
# shadow, primary state layers on rows.
{
  inputs,
  config,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  m = config.lib.palette.muted;
  sans = config.stylix.fonts.sansSerif.name;
  # Deliberately NOT visuals.nix's windowRounding (16) — M3 puts dialogs a step
  # above containers, so these two are meant to differ. Don't reconcile them.
  panelRounding = 28;
in {
  imports = [inputs.walker.homeManagerModules.default];

  programs.walker = {
    enable = true;
    # HM module manages a systemd --user service for the daemon, so first
    # keystroke is instant. Replaces the hand-rolled anyrun-daemon unit.
    runAsService = true;

    config = {
      theme = "material";

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
      # accent chips into subtle on-surface-variant labels.
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

    themes.material = {
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

        /* Catppuccin's ramp is base02/03/04 — base01 is `mantle`, darker than
           base00. base04 is 2.46:1 as text, hence the muted tone instead. */
        @define-color surface ${c.base00};
        @define-color surface_container ${c.base02};
        @define-color surface_container_high ${c.base03};
        @define-color outline ${c.base04};
        @define-color on_surface ${c.base05};
        @define-color on_surface_variant ${m.text};
        @define-color primary ${c.base0D};

        /* Outer layer-shell window — transparent so only .box-wrapper draws. */
        window {
          background-color: transparent;
        }

        /* Opaque — blur is off globally (visuals.nix), so a translucent panel
           would show raw wallpaper rather than frosting it. */
        .box-wrapper {
          background-color: @surface_container;
          border-radius: ${toString panelRounding}px;
          padding: 8px;
          margin: 24px; /* breathing room for shadow to render */
          box-shadow:
            0 1px 3px 0 rgba(0, 0, 0, 0.3),
            0 4px 8px 3px rgba(0, 0, 0, 0.15);
          min-width: 640px;
        }

        /* No fill of its own — the divider below separates query from results. */
        .input {
          background-color: transparent;
          color: @on_surface;
          caret-color: @primary;
          padding: 14px 20px 16px 20px;
          font-size: 1.35em;
          font-weight: 400;
        }

        .input placeholder {
          color: @on_surface_variant;
        }

        .list {
          background-color: transparent;
          padding: 8px 0 0 0;
          border-top: 1px solid @outline;
        }

        /* 26px == half the row height, so the pill closes. */
        .item-box {
          padding: 10px 16px;
          border-radius: 26px;
        }

        /* M3 state layers — one token, two intensities. */
        child:hover .item-box,
        row:hover .item-box {
          background-color: alpha(@primary, 0.08);
        }

        child:selected .item-box,
        row:selected .item-box {
          background-color: alpha(@primary, 0.16);
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

        .item-text {
          color: @on_surface;
          font-size: 1em;
          font-weight: 400;
        }

        /* Most providers don't populate subtext; calc previews and file
           paths do. */
        .item-subtext {
          color: @on_surface_variant;
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
          padding: 10px 8px 2px 8px;
          border-top: 1px solid @outline;
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

        /* Action name — top line of each chip. */
        .keybind-label {
          color: @on_surface_variant;
          font-size: 0.8em;
          font-weight: 500;
        }

        /* Key combo glyph (bottom line). tabular nums so glyphs like ↵/↑/↓
           sit on their own baseline and ⌘+digit combos don't shift width. */
        .keybind-bind {
          color: @on_surface_variant;
          font-size: 0.78em;
          font-feature-settings: "tnum";
        }

        /* Per-row quick-activation chip (F1-F4), shaped as an M3 assist chip.
           tnum + min-width keep them identical in width — proportional digits
           render `1` narrower, which shifted F1 right of F2-F4. min-width is
           the safety net for fonts that ignore font-feature-settings. */
        .item-quick-activation {
          background-color: transparent;
          color: @on_surface_variant;
          border: 1px solid @outline;
          border-radius: 8px;
          padding: 2px 8px;
          font-size: 0.8em;
          font-weight: 500;
          font-feature-settings: "tnum";
          min-width: 18px;
        }

        /* "No Results" empty-state label. Default would render at full
           foreground — way too loud for a "nothing found" message. */
        .placeholder {
          color: @on_surface_variant;
          font-size: 1.1em;
          padding: 24px;
        }

        /* Scrollbar is set to opacity:0 in walker default theme — keep
           that, but explicitly override here so any GTK4 default reset
           doesn't bring it back. */
        scrollbar {
          opacity: 0;
        }
      '';
    };
  };

  wayland.windowManager.hyprland.settings = {
    # SUPER+space — same bind anyrun owned.
    bind = ["SUPER,space,exec,walker"];

    # Scale up in place rather than slide from an edge. Only the style can be
    # overridden per-layer — timing/curve still come from the global layersIn.
    layerrule = ["animation popin 88%, match:namespace walker"];
  };

  # Bundled into SUPER+SHIFT+R via the reload pipeline in binds.nix.
  wayland.windowManager.hyprland.reload.commands.elephant = "systemctl --user try-restart elephant.service";
}
