# LosslessCut with a desktop entry.
_: _final: prev: {
  losslesscut = prev.losslesscut-bin.overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
                mkdir -p $out/share/applications
                cat > $out/share/applications/losslesscut.desktop << EOF
        [Desktop Entry]
        Name=LosslessCut
        Comment=Swiss army knife of lossless video/audio editing
        Exec=$out/bin/losslesscut %F
        Icon=losslesscut
        Type=Application
        Categories=AudioVideo;Video;AudioVideoEditing;
        MimeType=video/mp4;video/x-matroska;video/webm;video/quicktime;
        StartupWMClass=LosslessCut
        EOF
      '';
  });
}
