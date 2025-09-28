{pkgs, ...}: {
  #imports = [ ./foo.nix ];

  home.packages = builtins.attrValues {
    inherit
      (pkgs)
      # Development
      tokei
      # Productivity
      drawio
      # Media production
      obs-studio
      ;
  };
}
