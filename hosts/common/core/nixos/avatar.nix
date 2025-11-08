{
  lib,
  config,
  ...
}: let
  avatarPath = lib.custom.relativeToRoot "assets/avatars/${config.hostSpec.username}.jpg";
in {
  # Set user avatar for AccountsService (used by SDDM and Plasma)
  system.activationScripts.setUserAvatar = lib.mkIf (builtins.pathExists avatarPath) (lib.stringAfter ["users"] ''
    mkdir -p /var/lib/AccountsService/icons
    cp ${avatarPath} /var/lib/AccountsService/icons/${config.hostSpec.username}
  '');   
}