{lib, ...}: {
  imports = lib.flatten [
    (map (f: ./common/optional/${f}) [
      "development/aws.nix"
      "darwin/stylix.nix"
      "work.nix"
    ])

    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      "darwin/services/colima.nix"

      "helper-scripts"

      "browsers"

      "development"
      "development/postman.nix"
      # "development/ai"
      "development/gcloud.nix"
      "development/aws.nix"
      "development/languages"
      # "development/jupyter-notebook.nix"
      "development/terraform.nix"
      "development/tilt.nix"
      "development/virtualization"

      "secrets"
      "secrets/cachix.nix"
      "secrets/kubeconfig.nix"
      "secrets/ssh/server.nix"
      "secrets/1password-ssh.nix"

      "comms"
      "ghostty"
      "media/spicetify.nix"

      # "darwin/desktops/linux-esque"

      "secrets"
      "secrets/ai.nix"
    ]))
  ];
}
