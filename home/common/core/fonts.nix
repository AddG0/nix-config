{
  pkgs,
  lib,
  config,
  ...
}: {
  config = lib.mkIf (config.hostSpec.hostType != "server") {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      noto-fonts
    ];
  };
}
