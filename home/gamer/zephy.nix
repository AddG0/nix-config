{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers comms.discord])
    (with lib.custom.optional.home.gaming; [heroic minecraft])
    (with lib.custom.optional.home.media; [spicetify])
  ];

  desktops.defaultSession = "plasma";

  stylix = {
    enable = true;
    # Windows 11 dark shell: Mica base, layer greys, Fluent status colours and the default accent.
    base16Scheme = {
      scheme = "Windows 11";
      base00 = "202020";
      base01 = "2b2b2b";
      base02 = "323232";
      base03 = "5d5d5d";
      base04 = "9d9d9d";
      base05 = "ffffff";
      base06 = "f3f3f3";
      base07 = "fbfbfb";
      base08 = "ff99a4";
      base09 = "f7630c";
      base0A = "fce100";
      base0B = "6ccb5f";
      base0C = "99ebff";
      base0D = "60cdff";
      base0E = "b4a0ff";
      base0F = "c42b1c";
    };
    polarity = "dark";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
  };
}
