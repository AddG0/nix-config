_: {
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 3d";
    };
  };

  nix.gc.automatic = false;

  nix.settings.accept-flake-config = true;
}
