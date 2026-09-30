{config, ...}: let
  c = config.lib.stylix.colors.withHashtag;
  sans = config.stylix.fonts.sansSerif.name;
in {
  programs.wofi = {
    enable = true;
    settings = {
      width = 640;
      height = 480;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 32;
      gtk_dark = true;
    };
    style = ''
      /* ---- Full reset ---- */
      * {
        all: unset;
        font-family: "${sans}", sans-serif;
        font-size: 14px;
        outline: none;
        border: none;
        text-shadow: none;
        background-color: transparent;
      }

      /* ---- Surface panel ---- */
      window {
        all: unset;
        background-color: ${c.base02};
        border: none;
        border-radius: 28px;
        padding: 6px;
        box-shadow:
          0 1px 3px 0 rgba(0, 0, 0, 0.3),
          0 4px 8px 3px rgba(0, 0, 0, 0.15);
      }

      /* ---- Search bar ---- */
      /* Filled text field — a single active indicator, primary on focus. */
      #input {
        font-size: 15px;
        font-weight: 400;
        color: ${c.base05};
        background-color: transparent;
        border: none;
        border-bottom: 1px solid ${c.base04};
        border-radius: 0;
        padding: 12px 16px;
        margin: 8px 8px 4px 8px;
      }

      #input image {
        margin-right: 10px;
      }

      #input:focus {
        border-bottom-color: ${c.base0D};
      }

      #outer-box {
        margin: 0;
        padding: 0;
      }

      #scroll {
        margin: 0;
        padding: 0;
      }

      #inner-box {
        margin: 4px 8px 8px 8px;
      }

      /* ---- Entries ---- */
      #entry {
        padding: 10px 16px;
        margin: 2px 0;
        border-radius: 9999px;
        background-color: transparent;
        transition: all 0.2s cubic-bezier(0.2, 0, 0, 1);
      }

      #entry:nth-child(odd) {
        background-color: transparent;
      }

      #entry:nth-child(even) {
        background-color: transparent;
      }

      #entry:hover {
        background-color: alpha(${c.base0D}, 0.08);
      }

      #entry:selected {
        background-color: alpha(${c.base0D}, 0.16);
      }

      /* ---- Text ---- */
      #text {
        font-size: 14px;
        font-weight: 400;
        color: ${c.base05};
        margin-left: 12px;
      }

      #entry:selected #text {
        color: ${c.base05};
        font-weight: 500;
      }

      /* ---- Icons ---- */
      #img {
        margin-left: 4px;
        margin-right: 8px;
      }
    '';
  };

  wayland.windowManager.hyprland.settings = {
    bind = ["SUPER,space,exec,wofi --show drun"];
  };
}
