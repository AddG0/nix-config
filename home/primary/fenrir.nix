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
        # "development/java.nix"
        "jupyter-notebook"
        "comms"
        "development"
        "development/ide.nix"
        "development/tilt.nix"
        "development/node.nix"
        "development/aws.nix"
        # "development/misc-language-servers.nix"
        "ghostty"
        # "development/go.nix"
        "media/spicetify.nix"
        "development/virtualization"
        "development/ai"
        "secrets/1password.nix"
      ])
    ))
  ];
}
