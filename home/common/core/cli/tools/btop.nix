{
  lib,
  pkgs,
  ...
}: {
  programs.btop = {
    enable = true;
    package = pkgs.btop.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
      postFixup =
        (old.postFixup or "")
        + lib.optionalString pkgs.stdenv.isLinux ''
          wrapProgram $out/bin/btop \
            --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
        '';
    });
    settings = {
      color_theme = lib.mkDefault "catppuccin_mocha";
      theme_background = false; # make btop transparent
    };
  };
}
