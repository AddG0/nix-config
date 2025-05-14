{
  config,
  lib,
  ...
}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 3d";
    };
  };

  nix.gc.automatic = false;
}
