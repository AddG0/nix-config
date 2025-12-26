{
  lib,
  config,
  ...
}: let
  inherit (config.hostSpec) username;
  avatarsDir = lib.custom.relativeToRoot "assets/avatars";
  defaultAvatar = "${avatarsDir}/${username}.jpg";
  christmasAvatar = "${avatarsDir}/${username}-christmas.png";
  halloweenAvatar = "${avatarsDir}/${username}-halloween.png";
in {
  # Set user avatar for AccountsService (used by SDDM and Plasma)
  # Avatar changes based on the time of year
  system.activationScripts.setUserAvatar = lib.mkIf (builtins.pathExists defaultAvatar) (lib.stringAfter ["users"] ''
    mkdir -p /var/lib/AccountsService/icons
    CURRENT_MONTH=$(date +%m)
    if [ "$CURRENT_MONTH" = "12" ] && [ -f "${christmasAvatar}" ]; then
      cp ${christmasAvatar} /var/lib/AccountsService/icons/${username}
      echo "Using Christmas avatar for ${username}"
    elif [ "$CURRENT_MONTH" = "10" ] && [ -f "${halloweenAvatar}" ]; then
      cp ${halloweenAvatar} /var/lib/AccountsService/icons/${username}
      echo "Using Halloween avatar for ${username}"
    else
      cp ${defaultAvatar} /var/lib/AccountsService/icons/${username}
    fi
  '');
}
