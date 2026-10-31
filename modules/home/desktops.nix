# The desktop this user lands in when nothing else picks one; desktop-sessions' "Desktop" launcher reads the file.
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.desktops.defaultSession = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "plasma";
    description = "Key of the host's desktops.sessions this user lands in at autologin, Switch to Desktop and the greeter's Desktop entry. Inert on darwin.";
  };

  config = lib.mkIf (config.desktops.defaultSession != null && pkgs.stdenv.hostPlatform.isLinux) {
    xdg.configFile."desktops/default-session".text = config.desktops.defaultSession + "\n";
  };
}
