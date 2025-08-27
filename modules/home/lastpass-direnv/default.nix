{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.direnv.lastpass;
in {
  meta.maintainers = [];
  meta.doc = ''
    LastPass helpers for direnv configuration.
    
    Provides integration between direnv and LastPass CLI for loading secrets.
  '';

  options.programs.direnv.lastpass = {
    enable = mkEnableOption "LastPass direnv integration";
  };

  config = mkIf cfg.enable (let
    lastpassScript = pkgs.writeShellApplication {
      name = "lastpass.sh";
      text = builtins.readFile ./lastpass.sh;
      runtimeInputs = with pkgs; [
        lastpass-cli
        direnv
      ];
    };
  in {
    home.file.".config/direnv/lib/lastpass.sh" = {
      source = "${lastpassScript}/bin/lastpass.sh";
      executable = true;
    };
  });
}