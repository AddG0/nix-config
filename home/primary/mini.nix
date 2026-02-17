{lib, ...}: {
  imports = lib.flatten [
    ./common/core

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core"
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "helper-scripts"
        "development/languages/java.nix"
        "development/languages/node.nix"
        "development/jupyter-notebook.nix"
        "comms"
        "development/ide"
        "development/tilt.nix"
        "ghostty"
      ])
    ))
  ];
}
