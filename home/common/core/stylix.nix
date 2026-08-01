{
  inputs,
  lib,
  ...
}: {
  # Import the Stylix HM module everywhere so config.lib.stylix.colors is always available to core modules like fzf.
  imports = [inputs.stylix.homeModules.stylix];

  # Lets colors resolve while stylix.enable stays false.
  stylix.base16Scheme = lib.mkDefault "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";
}
