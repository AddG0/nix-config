{
  # nix-your-shell: Makes nix shell/develop work with nushell
  # Disable default integration because it uses `source` which doesn't export defs
  programs.nix-your-shell = {
    enable = true;
    enableNushellIntegration = true;
  };
}
