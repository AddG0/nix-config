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
      # intel-gpu-tools and rocm-smi are x86-only; aarch64 hosts (Pi) skip the wrap.
      postBuild = lib.optionalString (pkgs.stdenv.isLinux && pkgs.stdenv.hostPlatform.isx86_64) ''
        wrapProgram $out/bin/btop \
          --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib:${pkgs.intel-gpu-tools}/lib:${pkgs.rocmPackages.rocm-smi}/lib"
      '';
    };
    settings = {
      color_theme = lib.mkDefault "catppuccin_mocha";
      theme_background = false; # make btop transparent
    };
  };
}
