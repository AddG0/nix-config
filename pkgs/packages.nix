# Shared package definitions - used by both overlay and flake-module
# This keeps packages lazy - they're only evaluated when accessed
# Namespaces with multiple packages have their own default.nix for modularity
pkgs: let
  awsvpnShared = import ./awsvpnclient/shared.nix pkgs;
in {
  # Development tools
  awsvpnclient = pkgs.callPackage ./awsvpnclient/application.nix {shared = awsvpnShared;};
  awsvpnclient-service = pkgs.callPackage ./awsvpnclient/service.nix {shared = awsvpnShared;};
  gke-gcloud-auth-plugin = pkgs.callPackage ./gke-gcloud-auth-plugin {};
  kubevpn = pkgs.callPackage ./kubevpn {};
  openhands = pkgs.callPackage ./openhands {};
  claude-flow = pkgs.callPackage ./claude-flow {};
  wifiman-desktop = pkgs.callPackage ./wifiman-desktop {};
  superpowers-skills = pkgs.callPackage ./superpowers-skills {};
  context-engineering-kit = pkgs.callPackage ./context-engineering-kit {};
  claude-code-plugins = pkgs.callPackage ./claude-code-plugins {};
  claude-code-skills-collection = pkgs.callPackage ./claude-code-skills-collection {};

  # OpenTelemetry
  opentelemetry-javaagent = pkgs.callPackage ./opentelemetry-javaagent {};

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
