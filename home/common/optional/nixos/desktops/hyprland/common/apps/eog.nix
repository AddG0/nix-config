{pkgs, ...}: {
  xdg.mimeApps = {
    defaultApplications = {
      "image/png" = "org.gnome.eog.desktop";
    };
  };

  home.packages = with pkgs; [
    eog
  ];
}
