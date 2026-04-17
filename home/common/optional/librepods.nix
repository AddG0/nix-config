{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  librepods = pkgs.symlinkJoin {
    name = "librepods-stylix";
    paths = [pkgs.librepods];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/librepods" \
        --set QT_STYLE_OVERRIDE "" \
        --set QT_QUICK_CONTROLS_STYLE Universal \
        --set QT_QUICK_CONTROLS_UNIVERSAL_THEME Dark \
        --set QT_QUICK_CONTROLS_UNIVERSAL_ACCENT "${c.base0D}" \
        --set QT_QUICK_CONTROLS_UNIVERSAL_BACKGROUND "${c.base00}" \
        --set QT_QUICK_CONTROLS_UNIVERSAL_FOREGROUND "${c.base05}"
    '';
  };
in {
  home.packages = [librepods];

  xdg.autostart = {
    enable = true;
    entries = [
      "${librepods}/share/applications/me.kavishdevar.librepods.desktop"
    ];
  };
}
