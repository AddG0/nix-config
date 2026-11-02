# Stylix theme for hyprtoolkit apps, such as xdph's hyprland-share-picker.
{config, ...}: let
  c = config.lib.stylix.colors;
  argb = hex: "0xFF${hex}";
in {
  # FLAKE-UPDATE: drop once stylix ships a hyprtoolkit target.
  programs.hyprtoolkit = {
    enable = true;
    # The apps link hyprtoolkit themselves; this only writes its config.
    package = null;
    settings = {
      background = argb c.base00;
      base = argb c.base01;
      alternate_base = argb c.base02;
      text = argb c.base05;
      bright_text = argb c.base07;
      link_text = argb c.base0D;
      accent = argb c.base0D;
      accent_secondary = argb c.base0E;
      font_family = config.stylix.fonts.sansSerif.name;
      font_family_monospace = config.stylix.fonts.monospace.name;
    };
  };
}
