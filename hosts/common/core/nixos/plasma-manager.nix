# plasma-manager for every user, so home modules can set `programs.plasma.*` ungated; it writes nothing until `programs.plasma.enable`.
{inputs, ...}: {
  home-manager.sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];
}
