# checks/formatting.nix - Code formatting validation with treefmt
{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  perSystem = {config, ...}: {
    # Comprehensive formatting with treefmt-nix
    treefmt = {
      # Used to find the project root
      projectRootFile = "flake.nix";

      programs = {
        alejandra.enable = true;
        deadnix.enable = true;
        statix.enable = true;
        shellcheck.enable = true;
        shfmt.enable = true;
        prettier.enable = true;
        yamlfmt.enable = true;
      };

      settings = {
        formatter.shellcheck.options = [
          "--external-sources"
          "--source-path=SCRIPTDIR"
        ];
        formatter.shfmt.includes = [
          "*.envrc"
          "*.bashrc"
          "*.bash_profile"
          "*.zshrc"
        ];
        global.excludes = [
          "*.age"
          "*.sops.*"
          "secrets/*"
          "*.pem"
          "*.pub"
          "result"
          "result-*"
          ".direnv"
          "*.lock"
          ".git/*"
          ".gitignore"
          ".gitmodules"
          "*.md"
          "*.txt"
          "*.conf"
          "*.config"
          "*.toml"
          "*.yaml"
          "*.yml"
          "scripts/*"
          "home/common/optional/gaming/minecraft/modpacks/*/overrides/**"
        ];
      };
    };

    # Use treefmt as the formatter
    formatter = config.treefmt.build.wrapper;
  };
}
