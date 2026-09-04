{
  pkgs,
  inputs,
  lib,
  config,
  ...
}: {
  # FLAKE-UPDATE: drop once stylix sets home.pointerCursor.enable itself.
  # stylix supplies pointerCursor.{name,package,size} but not `enable` (now
  # required by home-manager). Gate on stylix.enable too, or hosts that disable
  # stylix (e.g. plasma) enable a nameless cursor and eval fails.
  home.pointerCursor.enable =
    config.stylix.enable
    && config.stylix.cursor != null
    && pkgs.stdenv.hostPlatform.isLinux;

  # Material Design 3 theme. Stylix is the top-level theming engine — all visual
  # values (colors, fonts, opacities, cursor) live here so every stylix-aware
  # app (noctalia, KDE, GTK, terminals, etc.) inherits a consistent look.
  #
  # Non-obvious bits:
  #   - RobotoMono's "Nerd Font" build is the patched one; plain roboto-mono
  #     has no icon glyphs.
  #   - Catppuccin's elevation ramp is base02/03/04 (surface0/1/2) — base01 is
  #     `mantle`, *darker* than base00, so it is never a container tone.
  #   - The cursor stays Bibata: material-cursors is XCursor-only, so it loses
  #     hyprcursor rendering.
  #   - Opacity is 1.0 everywhere; M3 conveys depth with elevation, not alpha.
  stylix = {
    enable = true;
    image = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Nexus/contents/images_dark/5120x2880.png";
    base16Scheme = "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    fonts = {
      sansSerif = {
        package = pkgs.roboto;
        name = "Roboto";
      };
      serif = {
        package = pkgs.roboto;
        name = "Roboto";
      };
      monospace = {
        package = pkgs.nerd-fonts.roboto-mono;
        name = "RobotoMono Nerd Font";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        terminal = 12;
        desktop = 11;
        popups = 12;
      };
    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 1.0;
    };
    polarity = "dark";
    # colloid-icon-theme is Linux-only; skip icon theming on Darwin.
    icons = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      enable = true;
      package = pkgs.colloid-icon-theme;
      dark = "Colloid-Dark";
      light = "Colloid-Light";
    };

    # Stylix recolors adw-gtk3 but leaves its shapes alone. Layering the M3
    # shape scale on top keeps stylix the single colour source — a Material GTK
    # theme like orchis would pin the palette to that theme instead.
    targets.gtk.extraCss = lib.mkIf pkgs.stdenv.hostPlatform.isLinux ''
      window, .background { border-radius: 16px; }
      popover, popover > contents, menu, .context-menu { border-radius: 12px; }
      .card, frame, .frame { border-radius: 12px; }

      button, .text-button, .toggle { border-radius: 9999px; }
      button.circular, button.image-button { border-radius: 9999px; }
      switch, switch slider { border-radius: 9999px; }
      radio { border-radius: 9999px; }
      check { border-radius: 2px; }

      /* Filled text field: rounded top, square bottom under the active line. */
      entry, .entry, spinbutton { border-radius: 4px 4px 0 0; }

      scale slider, progressbar progress, progressbar trough,
      levelbar block, scrollbar slider { border-radius: 9999px; }

      notebook > header > tabs > tab { border-radius: 8px 8px 0 0; }
      list > row, .list-row { border-radius: 9999px; }
      tooltip, tooltip.background { border-radius: 4px; }
    '';
  };
}
