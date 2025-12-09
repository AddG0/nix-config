{
  config,
  self,
  lib,
  ...
}: {
  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    # registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # See https://jackson.dev/post/nix-reasonable-defaults/
      connect-timeout = 5;
      log-lines = 25;
      min-free = 128000000; # 128MB
      max-free = 1000000000; # 1GB

      # Conditional max-jobs based on whether remote builders are enabled
      # If totalRemoteJobs is 0 (no compatible remote builders): use "auto" for local builds
      # Otherwise: use total maxJobs from all remote builders (auto-calculated)
      max-jobs = if config.nix.remoteBuilder.enableClient && config.nix.remoteBuilder.totalRemoteJobs > 0
                 then config.nix.remoteBuilder.totalRemoteJobs
                 else "auto";
      cores = 0; # Let each build use all available cores on the builder (auto-detect)

      trusted-users = ["root" config.hostSpec.username];

      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-nix-path = "nixpkgs=flake:nixpkgs";
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://anyrun.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
        "https://nixpkgs-python.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
        "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      ];
      warn-dirty = false;
    };

    # distributedBuilds and buildMachines are configured in nix-remote-builder.nix

    optimise.automatic = true;
  };

  nixpkgs = {
    # you can add global overlays here
    overlays = [
      self.overlays.default
    ];
    # Allow unfree packages
    config = {
      allowUnfree = true;
    };
  };
}
