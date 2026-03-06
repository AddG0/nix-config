{
  lib,
  pkgs,
  ...
}: {
  programs.btop = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "btop-${pkgs.btop.version}";
      paths = [pkgs.btop];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = lib.optionalString pkgs.stdenv.isLinux ''
        wrapProgram $out/bin/btop \
          --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib:${pkgs.rocmPackages.rocm-smi}/lib"
      '';
    };
    settings = {
      color_theme = lib.mkDefault "catppuccin_mocha";
      theme_background = false; # make btop transparent
    };
  };
}
