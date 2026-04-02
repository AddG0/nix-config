# Shared package definitions - used by both overlay and flake-module
# This keeps packages lazy - they're only evaluated when accessed
# Namespaces with multiple packages have their own default.nix for modularity
pkgs: {
  # Development tools
  bootdev-cli = pkgs.callPackage ./bootdev-cli {};
  gke-gcloud-auth-plugin = pkgs.callPackage ./gke-gcloud-auth-plugin {};
  openhands = pkgs.callPackage ./openhands {};
  wifiman-desktop = pkgs.callPackage ./wifiman-desktop {};
  superpowers-skills = pkgs.callPackage ./superpowers-skills {};
  context-engineering-kit = pkgs.callPackage ./context-engineering-kit {};
  claude-code-plugins = pkgs.callPackage ./claude-code-plugins {};
  claude-code-skills-collection = pkgs.callPackage ./claude-code-skills-collection {};
  anthropic-skills = pkgs.callPackage ./anthropic-skills {};
  claude-code-skill-factory = pkgs.callPackage ./claude-code-skill-factory {};
  claude-hud = pkgs.callPackage ./claude-hud {};
  node-sqlite3 = pkgs.callPackage ./node-sqlite3 {};

  # OpenTelemetry
  opentelemetry-javaagent = pkgs.callPackage ./opentelemetry-javaagent {};

  # gRPC tools
  protoc-gen-grpc-kotlin = pkgs.callPackage ./protoc-gen-grpc-kotlin {};

  # System utilities
  bt-proximity-monitor = pkgs.callPackage ./bt-proximity-monitor {};
  bt-scan = pkgs.callPackage ./bt-scan {};
  helium = pkgs.callPackage ./helium {};
  librepods = pkgs.callPackage ./librepods {};
  timezone-hover = pkgs.callPackage ./timezone-hover {};

  # Desktop environment
  blueprint = pkgs.callPackage ./blueprint {};
  claude-desktop = pkgs.callPackage ./claude-desktop {};
  rofi-presets = pkgs.callPackage ./rofi-presets {};

  # KDE/KWin - modular namespace
  kwin-scripts = import ./kwin-scripts pkgs;

  # Grafana plugins - modular namespace
  grafana-plugins = import ./grafana-plugins pkgs;

  # Themes - modular namespace with nested structure
  themes = import ./themes pkgs;
}
