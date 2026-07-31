{
  config,
  lib,
  ...
}: {
  programs.fusion360.enable = true;

  # Firefox/Zen blocks redirect-triggered external schemes, so Fusion's adskidmgr://
  # login callback never fires unless the scheme is whitelisted.
  programs.zen-browser.profiles.default.settings = lib.mkIf (config.programs.zen-browser.enable or false) {
    "network.protocol-handler.external.adskidmgr" = true;
    "network.protocol-handler.expose.adskidmgr" = false;
    "network.protocol-handler.warn-external.adskidmgr" = false;
  };
}
