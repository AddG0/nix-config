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

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  # Carapace custom spec files (auto-discovered from ./carapace/specs/)
  # Specs define completions for commands that don't have built-in Carapace support
  home.file = specFileAttrs;

  # Enable Carapace bridges for bash/zsh/fish completions
  # This allows Carapace to bridge completions from other shells
  programs.nushell.extraEnv = ''
    $env.CARAPACE_BRIDGES = 'zsh,fish,bash'
  '';
}
