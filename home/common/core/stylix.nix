{
  osConfig ? null,
  inputs,
  lib,
  ...
}: {
  # Import the Stylix HM module everywhere so config.lib.stylix.colors is always available to core modules like fzf.
  imports = [inputs.stylix.homeModules.stylix];

  stylix = {
    # Lets colors resolve while stylix.enable stays false.
    base16Scheme = lib.mkDefault "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";

    # Stylix's NixOS module does this itself, but only when stylix is enabled on the host, not just in home-manager.
    overlays.enable = lib.mkIf (osConfig.home-manager.useGlobalPkgs or false) false;
  };
}
