_: {
  programs.zathura.enable = true; # default package bundles the mupdf PDF backend

  xdg.mimeApps.defaultApplications."application/pdf" = "org.pwmt.zathura.desktop";
}
