{pkgs, ...}: {
  home.packages = with pkgs; [
    vlc
  ];

  # VLC's smb:// is SMBv1-only (libdsm); without the claim KIO hands it a kio-fuse path.
  xdg.dataFile."applications/vlc.desktop".source = pkgs.runCommand "vlc.desktop" {} ''
    sed '/^X-KDE-Protocols=/s/,smb//' ${pkgs.vlc}/share/applications/vlc.desktop > $out
  '';

  xdg.mimeApps = {
    defaultApplications = {
      "video/x-msvideo" = ["vlc.desktop"];
      "video/mp4" = ["vlc.desktop"];
      "video/mpeg" = ["vlc.desktop"];
      "video/ogg" = ["vlc.desktop"];
      "video/webm" = ["vlc.desktop"];
      "video/x-matroska" = ["vlc.desktop"];
      "video/x-flv" = ["vlc.desktop"];
      "video/quicktime" = ["vlc.desktop"];
      "video/3gpp" = ["vlc.desktop"];
      "video/3gpp2" = ["vlc.desktop"];
      "video/x-ms-wmv" = ["vlc.desktop"];
    };
  };
}
