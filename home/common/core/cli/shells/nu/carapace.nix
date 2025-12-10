{pkgs, ...}: let
  # Carapace expects specs in different locations per platform
  # macOS: ~/Library/Application Support/carapace/specs
  # Linux: ~/.config/carapace/specs (uses XDG)
  specPath =
    if pkgs.stdenv.isDarwin
    then "Library/Application Support/carapace/specs/kind.yaml"
    else ".config/carapace/specs/kind.yaml";
in {
  # Carapace - Multi-shell completion engine
  # https://carapace.sh/

  home.packages = with pkgs; [
    carapace # Multi-shell completion
  ];

  # Carapace custom spec files
  # Specs define completions for commands that don't have built-in Carapace support
  home.file.${specPath}.source = ./carapace/specs/kind.yaml;

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
