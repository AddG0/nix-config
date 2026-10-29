# noctalia-greeter on greetd as the login screen, matching the Noctalia shell.
#
# We only override default_session.user: upstream reads it but doesn't set it,
# and ./_greetd.nix defaults it to the primary user — the greeter must run as `greeter`.
#
# Wallpaper / output layout / default_user live in
# /var/lib/noctalia-greeter/greeter.conf, populated by the shell's "Sync Now"
# or written by hand. Only cursor is wired here, from stylix.
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
    else config.home-manager.users.${config.hostSpec.primaryUsername}.stylix.cursor or null;
in {
  imports = [
    inputs.noctalia-greeter.nixosModules.default
    ./_greetd.nix
  ];

  services.displayManager.noctalia-greeter = {
    enable = true;
    settings.cursor = lib.mkIf (cursor != null) {
      theme = cursor.name;
      inherit (cursor) size package;
    };
  };

  services.greetd.settings.default_session.user = lib.mkForce "greeter";
}
