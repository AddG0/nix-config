{lib, ...}: {
  imports = lib.flatten [
    ./common/core
    (map (f: ./common/optional/${f}) [
      "development/aws.nix"
    ])

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core"
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "helper-scripts"
        # "development/java.nix"
        "development/jupyter-notebook.nix"
        "secrets/kubeconfig.nix"
        "comms"
        "development"
        "development/ide.nix"
        "development/tilt.nix"
        "development/node.nix"
        # "development/misc-language-servers.nix"
        "secrets/ssh/server.nix"
        "ghostty"
        "secrets"
        "secrets/cachix.nix"
        # "development/go.nix"
        "media/spicetify.nix"
        "development/virtualization"
        "development/ai"
        "secrets/1password.nix"
        "development/gcloud.nix"
      ])
    ))
  ];
}
