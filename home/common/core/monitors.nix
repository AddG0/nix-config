# The host's display.monitors, as the default for every user's home; a user can still override it.
{
  osConfig ? null,
  lib,
  ...
}: {
  display = lib.mkIf (osConfig != null) {
    monitors = lib.mkDefault osConfig.display.monitors;
    defaultMonitor.enable = lib.mkDefault osConfig.display.defaultMonitor.enable;
  };
}
