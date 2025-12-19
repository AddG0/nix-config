# checks/pre-commit-checks.nix - Pre-commit hooks validation
{inputs, ...}: {
  perSystem = {system, ...}: {
    checks = {
      pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
        src = ./.;
        default_stages = ["pre-commit"];
        hooks = {
          check-added-large-files.enable = true;
          check-case-conflicts.enable = true;
          check-executables-have-shebangs.enable = true;
          check-shebang-scripts-are-executable.enable = true;
          check-merge-conflicts.enable = true;
          detect-private-keys.enable = true;
          fix-byte-order-marker.enable = true;
          mixed-line-endings.enable = true;
          trim-trailing-whitespace.enable = true;

          forbid-submodules = {
            enable = false;
            name = "forbid submodules";
            description = "forbids any submodules in the repository";
            language = "fail";
            entry = "submodules are not allowed in this repository:";
            types = ["directory"];
          };

          # disabled because of typesfmt is no longer maintained
          # destroyed-symlinks = {
          #   enable = true;
          #   name = "destroyed-symlinks";
          #   description = "detects symlinks which are changed to regular files with a content of a path which that symlink was pointing to.";
          #   package = inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks;
          #   entry = "${inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks}/bin/destroyed-symlinks";
          #   types = ["symlink"];
          # };

          alejandra.enable = true;
          statix.enable = true;
          shfmt = {
            enable = true;
            excludes = ["\\.zsh$"]; # zsh has syntax shfmt doesn't understand
          };

          end-of-file-fixer.enable = true;
        };
      };
    };
  };
}
