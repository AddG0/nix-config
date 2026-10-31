# noctalia-greeter on greetd as the login screen, matching the Noctalia shell.
#
# Cursor comes from stylix and the output layout from the host's
# display.monitors; wallpaper and default_user come from the shell's "Sync Now".
{
  inputs,
  config,
  lib,
  ...
}: let
  # The system stylix cursor if set, else the primary user's; null leaves the greeter's default.
  systemCursor = config.stylix.cursor or null;
  cursor =
    if systemCursor != null
    then systemCursor
    else primaryUser.stylix.cursor or null;
  primaryUser = config.home-manager.users.${config.hostSpec.primaryUsername};
  monitors = lib.filter (m: m.enabled) config.display.monitors;
  perOutput = f: lib.concatMapStringsSep "; " (m: "${m.output}:${f m}") monitors;
in {
  imports = [
    inputs.noctalia-greeter.nixosModules.default
    ./_greetd.nix
    (import ./_retain-splash.nix {})
  ];

  services.displayManager.noctalia-greeter = {
    enable = true;
    settings = {
      cursor = lib.mkIf (cursor != null) {
        theme = cursor.name;
        inherit (cursor) size package;
      };
      output = lib.mkIf (monitors != []) {
        layout = perOutput (m: "${toString m.x},${toString m.y}");
        transforms = perOutput (m: m.transform);
        scales = perOutput (m: toString m.scale);
        refresh_rate = perOutput (m: toString m.refreshRate);
      };
    };
  };
}
