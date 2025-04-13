{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    zen-browser
  ];

  # xdg.mimeApps = {
  #   defaultApplications = {
  #     "text/html" = "zen-browser.desktop";
  #     "x-scheme-handler/http" = "zen-browser.desktop";
  #     "x-scheme-handler/https" = "zen-browser.desktop";
  #   };
  # };
}
