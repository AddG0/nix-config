{pkgs, ...}: let
  # DaVinci Resolve's bundled Qt lacks Wayland support, force XWayland
  davinci = pkgs.symlinkJoin {
    name = "davinci-resolve";
    paths = [pkgs.davinci-resolve];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb
    '';
  };
in {
  home.packages = [davinci];
}
