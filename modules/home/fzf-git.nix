{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.fzf-git;
in {
  meta.maintainers = [];

  options.programs.fzf-git = {
    enable = mkEnableOption "fzf-git, git utilities for fzf";

    package = mkOption {
      type = types.package;
      default = pkgs.stdenv.mkDerivation {
        pname = "fzf-git";
        version = "unstable-2023-12-14";

        src = pkgs.fetchFromGitHub {
          owner = "junegunn";
          repo = "fzf-git.sh";
          rev = "main";
          hash = null;
        };

        dontBuild = true;

        installPhase = ''
          mkdir -p $out/share/fzf-git
          cp fzf-git.sh $out/share/fzf-git/
        '';
      };
      description = "The fzf-git package to use";
    };

    enableZshIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Zsh integration.";
    };

    enableBashIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Bash integration.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      [
        cfg.package
        bat
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        fzf
        git
        perl
      ];

    programs.zsh.initContent = mkIf cfg.enableZshIntegration ''
      source ${cfg.package}/share/fzf-git/fzf-git.sh
    '';

    programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
      source ${cfg.package}/share/fzf-git/fzf-git.sh
    '';
  };
}
