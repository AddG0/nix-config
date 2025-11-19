# checks/formatting.nix - Code formatting validation with treefmt
{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  perSystem = {config, ...}: {
    # Comprehensive formatting with treefmt-nix
    treefmt = {
      # Used to find the project root
      projectRootFile = "flake.nix";

      # Enable formatters
      programs.alejandra.enable = true;
      programs.deadnix.enable = true;
      programs.statix.enable = true;
      programs.shellcheck.enable = true;
      programs.shfmt.enable = true;
      programs.prettier.enable = true;
      programs.yamlfmt.enable = true;

      # Configure shellcheck
      settings.formatter.shellcheck.options = [
        "--external-sources"
        "--source-path=SCRIPTDIR"
      ];

      # Configure shfmt to include common shell files
      settings.formatter.shfmt.includes = [
        "*.envrc"
        "*.bashrc"
        "*.bash_profile"
        "*.zshrc"
      ];

      # Global excludes
      settings.global.excludes = [
        # Secrets and sensitive files
        "*.age"
        "*.sops.*"
        "secrets/*"
        "*.pem"
        "*.pub"

        # Build artifacts
        "result"
        "result-*"
        ".direnv"

        # Nix-specific
        "*.lock"

        # Version control
        ".git/*"
        ".gitignore"
        ".gitmodules"

        # Documentation that shouldn't be auto-formatted
        "*.md"
        "*.txt"

        # Configuration files
        "*.conf"
        "*.config"
        "*.toml"
        "*.yaml"
        "*.yml"

        # Scripts directory
        "scripts/*"
      ];
    };

    # Use treefmt as the formatter
    formatter = config.treefmt.build.wrapper;
  };
}
