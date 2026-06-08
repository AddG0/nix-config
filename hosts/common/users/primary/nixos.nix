# nixos-only user attrs (merged per user)
{
  config,
  lib,
  ...
}: {
  isNormalUser = true;
  uid = 1000;
  extraGroups = let
    ifTheyExist = groups: lib.filter (group: lib.hasAttr group config.users.groups) groups;
  in
    lib.flatten [
      "wheel"
      (ifTheyExist [
        "audio"
        "video"
        "docker"
        "git"
        "networkmanager"
        "libvirtd"
      ])
    ];
}
