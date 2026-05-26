{
  config,
  lib,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
in {
  # A command-line fuzzy finder
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    # Colors derived from the active stylix base16 scheme so they track theme.
    colors = lib.mkDefault {
      "bg" = c.base00;
      "bg+" = c.base01;
      "fg" = c.base05;
      "fg+" = c.base05;
      "hl" = c.base08;
      "hl+" = c.base08;
      "header" = c.base08;
      "info" = c.base0E;
      "prompt" = c.base0E;
      "pointer" = c.base06;
      "marker" = c.base06;
      "spinner" = c.base06;
    };
  };
}
