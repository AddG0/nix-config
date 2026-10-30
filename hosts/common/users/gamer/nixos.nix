# nixos-only user attrs (merged per user)
{
  config,
  lib,
  ...
}: {
  isNormalUser = true;
  extraGroups = let
    ifTheyExist = groups: lib.filter (group: lib.hasAttr group config.users.groups) groups;
  in
    ifTheyExist [
      "audio"
      "video"
      "networkmanager"
    ];
}
