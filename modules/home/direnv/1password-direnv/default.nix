{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.direnv.onepassword;
in {
  meta.maintainers = [];
  meta.doc = ''
    1Password helpers for direnv configuration.
    
    Based on https://github.com/tmatilai/direnv-1password
    MIT licence - Copyright (c) 2022 Teemu Matilainen and contributors
  '';

  options.programs.direnv.onepassword = {
    enable = mkEnableOption "1Password direnv integration";
  };

  config = mkIf cfg.enable (let
    onePasswordScript = pkgs.writeShellApplication {
      name = "1password.sh";
      text = builtins.readFile ./1password.sh;
      runtimeInputs = with pkgs; [
        _1password-cli
        direnv
      ];
    };
  in {
    home.file.".config/direnv/lib/1password.sh" = {
      source = "${onePasswordScript}/bin/1password.sh";
      executable = true;
    };
  });
}