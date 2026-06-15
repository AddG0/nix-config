# noctalia-greeter — greetd login screen matching the Noctalia shell.
#
# greetd is a generic dependency (./greetd.nix), so importing *this* module is
# itself the signal that you want the noctalia greeter — there's no separate
# toggle. The upstream module builds default_session.command from the options
# below (at mkDefault); ./greetd.nix sets tuigreet's command at the weaker
# mkOptionDefault, so importing this lets the greeter's command win.
#
# We only override default_session.user: upstream reads it but doesn't set it,
# and tuigreet runs as the primary user — the greeter must run as `greeter`.
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
  cursor = config.stylix.cursor;
in {
  imports = [inputs.noctalia-greeter.nixosModules.default];

  programs.noctalia-greeter = {
    enable = true;
    settings.cursor = {
      theme = cursor.name;
      inherit (cursor) size package;
    };
  };

  services.greetd.settings.default_session.user = lib.mkForce "greeter";
}
