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
    # Let Atuin own Ctrl-R in zsh; fzf keeps its other widgets.
    historyWidget.zsh.command = "";
    # Colors derived from the active stylix base16 scheme so they track theme.
    colors = lib.mkMerge [
      # -1 = terminal default, so ghostty's translucency shows through; beats stylix's solid base00.
      {"bg" = lib.mkForce "-1";}
      (lib.mkDefault {
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
      })
    ];
  };
}
