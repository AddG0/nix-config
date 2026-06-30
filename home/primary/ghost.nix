{lib, ...}: {
  imports = lib.flatten [
    (map (f: ./common/optional/${f}) [
      ])

    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      "darwin/services/colima.nix"
      "helper-scripts"
    ]))
  ];
}
