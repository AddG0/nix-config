{lib, ...}: {
  imports = lib.flatten [
    ./common/core

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core" # required
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "helper-scripts"

        "development/gcloud.nix"
        "development/virtualization/kubernetes"
      ])
    ))
  ];
}
