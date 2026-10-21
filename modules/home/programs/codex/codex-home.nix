# CODEX_HOME relative to $HOME, spelled as upstream programs.codex's home.file keys: a leading slash when XDG.
{
  config,
  lib,
}:
if config.home.preferXdgDirectories
then "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex"
else ".codex"
