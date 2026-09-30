{lib, ...}: {
  imports = lib.flatten [
    lib.custom.suites.development.home
    lib.custom.suites.ai.home
    (with lib.custom.optional.home; [browsers])
    (with lib.custom.optional.home.development; [gcloud])
    (with lib.custom.optional.home.secrets; [sops])
    (with lib.custom.optional.primary; [stylix work])
    (with lib.custom.optional.primary.development; [
      # aws
    ])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
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
