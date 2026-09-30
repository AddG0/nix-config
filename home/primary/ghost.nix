{lib, ...}: {
  imports = lib.flatten [
    lib.custom.suites.development.home
    (with lib.custom.optional.home; [helper-scripts])
    (with lib.custom.optional.home.secrets; [sops])
    (with lib.custom.optional.home.services; [colima])
    (with lib.custom.optional.primary; [work])
  ];

  # Headless: no console login, so there is no gui/<uid> domain to bootstrap into.
  launchd.agents.colima-default.domain = "user";
}
