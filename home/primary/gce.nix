{lib, ...}: {
  imports = lib.flatten [
    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      "helper-scripts"

      "development/gcloud.nix"
      "development/virtualization/kubernetes"
    ]))
  ];
}
