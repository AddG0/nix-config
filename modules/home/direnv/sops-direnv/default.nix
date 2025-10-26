{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.direnv.sops-direnv;
in {
  meta.maintainers = [];

  options.programs.direnv.sops-direnv = {
    enable = mkEnableOption "sops-direnv, direnv integration for Mozilla SOPS";
  };

  config = mkIf cfg.enable (let
    sopsScript = pkgs.writeShellApplication {
      name = "use_sops.sh";
      text = builtins.readFile ./use_sops.sh;
      runtimeInputs = with pkgs; [
        sops
        direnv
        yq-go
      ];
    };
  in {
    home.file.".config/direnv/lib/use_sops.sh" = {
      source = "${sopsScript}/bin/use_sops.sh";
      executable = true;
    };
  });
}
