{
  imports = [
    # ./brave.nix
    ./chromium.nix
    # ./firefox.nix
    # ./floorp.nix
  ];

  # Set default browser here (change the .desktop file as needed)
  # Options: google-chrome.desktop, chromium.desktop, floorp.desktop, firefox.desktop, brave-browser.desktop
  xdg.mimeApps.defaultApplications = let
    browser = "google-chrome.desktop";
  in {
    "text/html" = browser;
    "x-scheme-handler/http" = browser;
    "x-scheme-handler/https" = browser;
  };
}
