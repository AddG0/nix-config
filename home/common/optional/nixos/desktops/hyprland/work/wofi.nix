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

      /* ---- Glass window (matches waybar) ---- */
      window {
        all: unset;
        background-color: alpha(${c.base00}, 0.45);
        border: 1px solid alpha(${c.base02}, 0.4);
        border-radius: 14px;
        padding: 6px;
      }

      /* ---- Search bar ---- */
      #input {
        font-size: 15px;
        font-weight: 500;
        color: ${c.base06};
        background-color: alpha(${c.base01}, 0.6);
        border: 1px solid alpha(${c.base02}, 0.4);
        border-radius: 10px;
        padding: 10px 16px;
        margin: 8px 8px 4px 8px;
      }

      #input image {
        margin-right: 10px;
      }

      #input:focus {
        border-color: alpha(${c.base0B}, 0.5);
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
        padding: 10px 14px;
        margin: 2px 0;
        border-radius: 8px;
        background-color: transparent;
        transition: all 0.12s ease;
      }

      #entry:nth-child(odd) {
        background-color: transparent;
      }

      #entry:nth-child(even) {
        background-color: transparent;
      }

      #entry:selected {
        background-color: alpha(${c.base0B}, 0.18);
      }

      /* ---- Text ---- */
      #text {
        font-size: 14px;
        font-weight: 500;
        color: ${c.base06};
        margin-left: 12px;
      }

      #entry:selected #text {
        color: ${c.base07};
        font-weight: 600;
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
    layerrule = [
      "blur on, match:namespace wofi"
      "ignore_alpha 0.3, match:namespace wofi"
    ];
  };
}
