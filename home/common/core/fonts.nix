{
  pkgs,
  lib,
  hostSpec,
  ...
}: {
  config = lib.mkIf (hostSpec.hostType != "server") {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      noto-fonts
      meslo-lgs-nf # MesloLGS NF. Used in Ghostty
    ];
  };
}
