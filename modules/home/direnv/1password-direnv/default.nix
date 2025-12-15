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

  # Note: We use writeText instead of writeShellApplication because this script
  # is sourced by direnv, and writeShellApplication adds PATH exports that would
  # override /run/wrappers/bin (where the setgid op wrapper lives on NixOS).
  config = mkIf cfg.enable {
    home.file.".config/direnv/lib/1password.sh" = {
      source = ./1password.sh;
      executable = true;
    };
  };
}
