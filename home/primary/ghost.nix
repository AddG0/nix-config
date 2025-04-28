{lib, ...}: {
  imports = [
    #################### Required Configs ####################
    common/core

    #################### Host-specific Optional Configs ####################
    common/optional/helper-scripts
    common/optional/development/java.nix
    common/optional/jupyter-notebook
    common/optional/secrets/kubeconfig.nix
    common/optional/comms
    common/optional/development
    common/optional/development/ide.nix
    common/optional/development/tilt.nix
    common/optional/development/node.nix
    common/optional/development/aws.nix
    common/optional/development/misc-language-servers.nix
    common/optional/secrets/ssh/server.nix
    common/optional/ghostty
    common/optional/secrets
    common/optional/secrets/cachix.nix
    common/optional/development/go.nix
    common/optional/media/spicetify.nix
    common/optional/development/virtualization
    common/optional/remote-desktop/mouseshare/lan-mouse.nix
  ];
}
