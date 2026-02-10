{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    ./common/core
    (map (f: ./common/optional/${f}) [
      "development/aws.nix"
      "work.nix"
    ])

    (map lib.custom.relativeToHome (
      [
        #################### Required Configs ####################
        "common/core"
      ]
      ++ (map (f: "common/optional/${f}") [
        #################### Host-specific Optional Configs ####################
        "helper-scripts"

        "development"
        "development/ai"
        "development/gcloud.nix"
        "development/aws.nix"
        "development/ide"
        "development/ide/vscode"
        # "development/java.nix"
        # "development/jupyter-notebook.nix"
        "development/node.nix"
        "development/terraform.nix"
        "development/tilt.nix"
        "development/virtualization"
        # "development/go.nix"
        # "development/misc-language-servers.nix"

        "secrets"
        "secrets/cachix.nix"
        "secrets/kubeconfig.nix"
        "secrets/ssh/server.nix"
        "secrets/1password-ssh.nix"

        "comms"
        "ghostty"
        "media/spicetify.nix"

        "darwin/desktops/linux-esque"
      ])
    ))
  ];
}
