{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./env.nix
    ./config.nix
    ./carapace.nix
  ];

  # nix-your-shell: Makes nix shell/develop work with nushell
  programs.nix-your-shell = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.nushell = {
    enable = true;
    # Plugins - conditionally enabled based on platform
    plugins = with pkgs.nushellPlugins;
      [
        polars # DataFrame operations - blazing fast data manipulation
        gstat # Git status as structured data
        query # Query JSON, XML, HTML, web data
        formats # Support for EML, ICS, INI, plist, VCF
        highlight # Syntax highlighting
        skim # Fuzzy finder integration
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        semver # Semantic version handling (Linux only)
        units # Unit conversions (Linux only)
      ];

    extraConfig = ''
      # Custom Keybindings
      # ----------------------------------------------------------------------------
      # Load keybindings from keybindings.nu
      source ${./keybindings.nu}
      $env.config = ($env.config | upsert keybindings $keybindings)
    '';
  };
}
