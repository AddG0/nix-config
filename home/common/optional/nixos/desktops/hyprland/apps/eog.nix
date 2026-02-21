{pkgs, ...}: {
  xdg.mimeApps = {
    defaultApplications = {
      "image/png" = "eog.desktop";
    };
  };

  home.packages = with pkgs; [
    eog
  ];
}
