{lib, ...}: {
  imports = lib.flatten [
    ./common

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core"
      ]
    ++ (map (f: "common/optional/${f}") [
      #################### Host-specific Optional Configs ####################
      "helper-scripts"
      "development/java.nix"
      "jupyter-notebook"
      "comms"
      "development/ide.nix"
      "development/tilt.nix"
      "development/node.nix"
      "development/misc-language-servers.nix"
      "ghostty"
    ])
    ))
  ];
}
