# CODEX_HOME relative to $HOME, spelled as upstream programs.codex's home.file keys: a leading slash when XDG.
{
  config,
  lib,
}: let
  inherit (config.programs.codex) package;
  # Upstream's isTomlConfig: its nullable package counts as the latest Codex when null; YAML-era Codex never read XDG.
  isTomlConfig = package == null || lib.versionAtLeast (lib.getVersion package) "0.2.0";
in
  if config.home.preferXdgDirectories && isTomlConfig
  then "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex"
  else ".codex"
