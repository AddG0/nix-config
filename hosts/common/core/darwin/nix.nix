{pkgs, ...}: {
  nix = {
    gc.automatic = true;

    # Garbage Collection
    gc = {
      options = "--delete-older-than 10d";
    };
  };

  environment.systemPackages = with pkgs; [
    nh
  ];
}
