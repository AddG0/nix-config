{pkgs, ...}: {
  services.lact = {
    enable = true;

    package = pkgs.symlinkJoin {
      name = "lact";
      paths = [pkgs.lact];
      postBuild = ''
        desktop=$out/share/applications/io.github.ilya_zlobintsev.LACT.desktop
        rm "$desktop"
        substitute ${pkgs.lact}/share/applications/io.github.ilya_zlobintsev.LACT.desktop "$desktop" \
          --replace-fail 'Keywords=AMD;GPU;Radeon;' \
            'Keywords=AMD;GPU;Radeon;Overclock;Overclocking;Undervolt;Fan;Tuning;'
      '';
    };
  };
}
