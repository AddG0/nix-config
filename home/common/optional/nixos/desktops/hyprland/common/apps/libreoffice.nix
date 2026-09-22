{pkgs, ...}: {
  home.packages = [pkgs.libreoffice-stable];

  xdg.mimeApps.defaultApplications = {
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "libreoffice-impress.desktop";
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "libreoffice-writer.desktop";
  };
}
