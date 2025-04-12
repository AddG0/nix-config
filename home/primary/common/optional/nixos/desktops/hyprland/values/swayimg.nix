{pkgs, ...}: {
  xdg.mimeApps = {
    defaultApplications = {
      "image/png" = "swayimg.desktop";
    };
  };

  home.packages = with pkgs; [
    swayimg
  ];
}
