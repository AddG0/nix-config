{lib, ...}: {
  imports = lib.flatten [
    (map (f: ./common/optional/${f}) [
      "work.nix"
    ])

    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      "darwin/services/colima.nix"
      "helper-scripts"

      "development"
      "secrets"
    ]))
  ];

  # Headless: no console login, so there is no gui/<uid> domain to bootstrap into.
  launchd.agents.colima-default.domain = "user";
}
