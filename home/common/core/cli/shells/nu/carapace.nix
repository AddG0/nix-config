{
  pkgs,
  lib,
  ...
}: let
  # Auto-discover all .yaml spec files in the specs directory
  specFiles = builtins.attrNames (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".yaml" name)
    (builtins.readDir ./carapace/specs)
  );

  # Generate home.file entries for all spec files
  # Platform-specific paths:
  # macOS: ~/Library/Application Support/carapace/specs
  # Linux: ~/.config/carapace/specs
  specFileAttrs = builtins.listToAttrs (
    map (file: {
      name =
        if pkgs.stdenv.isDarwin
        then "Library/Application Support/carapace/specs/${file}"
        else ".config/carapace/specs/${file}";
      value = {source = ./carapace/specs/${file};};
    })
    specFiles
  );
in {
  # Carapace - Multi-shell completion engine
  # https://carapace.sh/

  home.packages = with pkgs; [
    carapace # Multi-shell completion
  ];

  # Carapace custom spec files (auto-discovered from ./carapace/specs/)
  # Specs define completions for commands that don't have built-in Carapace support
  home.file = specFileAttrs;

  programs.nushell = {
    # Enable Carapace bridges for bash/zsh/fish completions
    # This allows Carapace to bridge completions from other shells
    extraEnv = ''
      $env.CARAPACE_BRIDGES = 'zsh,fish,bash'
    '';

    # Configure Carapace as the external completer
    # This handles completions for commands that don't have native Nushell support
    extraConfig = ''
      # Carapace External Completer
      # ----------------------------------------------------------------------------
      $env.config = ($env.config | upsert completions.external {
        enable: true
        max_results: 100
        completer: {|spans|
          carapace $spans.0 nushell ...$spans | from json
        }
      })
    '';
  };
}
