{pkgs, ...}: let
  # DaVinci Resolve's bundled Qt lacks Wayland support, force XWayland
  davinci = pkgs.symlinkJoin {
    name = "davinci-resolve-studio";
    paths = [pkgs.davinci-resolve-studio];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/davinci-resolve-studio \
        --set QT_QPA_PLATFORM xcb
    '';
  };
in {
  home.packages = [davinci];
}
