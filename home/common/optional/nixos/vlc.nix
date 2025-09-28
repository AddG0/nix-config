{pkgs, ...}: {
  home.packages = with pkgs; [
    vlc
  ];

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
