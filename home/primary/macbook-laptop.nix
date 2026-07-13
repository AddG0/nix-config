{lib, ...}: {
  imports = lib.flatten [
    (map (f: ./common/optional/${f}) [
      # "development/aws.nix"
      "stylix.nix"
      "work.nix"
    ])
    (map lib.custom.relativeToHome (map (f: "common/optional/${f}") [
      "browsers"

      "development"
      "development/ai"
      "development/gcloud.nix"

      "secrets"
      "secrets/1password-ssh.nix"
    ]))
  ];

  hostSpec = {
    primaryUsername = "addg";
    hostType = "laptop";
    hostPlatform = "aarch64-darwin";
    system.stateVersion = "25.05";
  };

  # Determinate Nix owns nix.conf and understands eval-cores/lazy-trees; no
  # published Nix package does. Disable home-manager's nix module so activation
  # uses the system Determinate Nix (no "unknown setting" warnings) and doesn't
  # manage ~/.config/nix/nix.conf, which Determinate and the user own.
  nix.enable = false;
}
