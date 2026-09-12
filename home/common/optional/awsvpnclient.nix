{
  inputs,
  config,
  ...
}: {
  imports = [inputs.awsvpnclient-nix.homeModules.default];

  programs.awsvpnclient = {
    enable = true;
    # Catppuccin maps base04 to surface2, leaving muted text at 2.5:1 on base00.
    palette = config.lib.stylix.colors // {base04 = config.lib.palette.muted.text;};
  };
}
