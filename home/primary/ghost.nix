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
}
