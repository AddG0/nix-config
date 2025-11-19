# Shared package definitions - used by both overlay and flake-module
# This keeps packages lazy - they're only evaluated when accessed
# Namespaces with multiple packages have their own default.nix for modularity
pkgs: {
  # Development tools
  awsvpnclient = pkgs.callPackage ./awsvpnclient {};
  gke-gcloud-auth-plugin = pkgs.callPackage ./gke-gcloud-auth-plugin {};
  kubevpn = pkgs.callPackage ./kubevpn {};
  openhands = pkgs.callPackage ./openhands {};
  claude-flow = pkgs.callPackage ./claude-flow {};

  # JetBrains - modular namespace
  jetbrains = import ./jetbrains pkgs;

  # Gaming
  bakkesmod = pkgs.callPackage ./bakkesmod {};
  bakkesmod-plugins = import ./bakkesmod-plugins pkgs;

  # System utilities
  bt-proximity-monitor = pkgs.callPackage ./bt-proximity-monitor {};
  bt-scan = pkgs.callPackage ./bt-scan {};
  helium = pkgs.callPackage ./helium {};
  librepods = pkgs.callPackage ./librepods {};
  timezone-hover = pkgs.callPackage ./timezone-hover {};

  # Desktop environment
  blueprint = pkgs.callPackage ./blueprint {};
  rofi-presets = pkgs.callPackage ./rofi-presets {};

  # KDE/KWin - modular namespace
  kwin-scripts = import ./kwin-scripts pkgs;

  # Grafana plugins - modular namespace
  grafana-plugins = import ./grafana-plugins pkgs;

  # Themes - modular namespace with nested structure
  themes = import ./themes pkgs;
}
