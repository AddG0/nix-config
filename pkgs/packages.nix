# Shared package definitions - used by both overlay and flake-module
# This keeps packages lazy - they're only evaluated when accessed
# Namespaces with multiple packages have their own default.nix for modularity
pkgs: rec {
  # Development tools
  bootdev-cli = pkgs.callPackage ./bootdev-cli {};
  kotlin-lsp = pkgs.callPackage ./kotlin-lsp {};
  gwq = pkgs.callPackage ./gwq {};
  gke-gcloud-auth-plugin = pkgs.callPackage ./gke-gcloud-auth-plugin {};
  openhands = pkgs.callPackage ./openhands {};
  wifiman-desktop = pkgs.callPackage ./wifiman-desktop {};
  claude-hud = pkgs.callPackage ./claude-hud {};
  gitlab-nvim = pkgs.callPackage ./gitlab-nvim {};
  node-sqlite3 = pkgs.callPackage ./node-sqlite3 {};
  ollama-zsh-completion = pkgs.callPackage ./ollama-zsh-completion {};

  # OpenTelemetry
  opentelemetry-javaagent = pkgs.callPackage ./opentelemetry-javaagent {};
  opentelemetry-method-args = pkgs.callPackage ./opentelemetry-method-args {inherit opentelemetry-javaagent;};
  opentelemetry-node = pkgs.callPackage ./opentelemetry-node {};

  # gRPC tools
  protoc-gen-grpc-kotlin = pkgs.callPackage ./protoc-gen-grpc-kotlin {};

  # System utilities
  bt-proximity-monitor = pkgs.callPackage ./bt-proximity-monitor {};
  bt-scan = pkgs.callPackage ./bt-scan {};
  helium = pkgs.callPackage ./helium {};
  timezone-hover = pkgs.callPackage ./timezone-hover {};

  # Desktop environment
  blueprint = pkgs.callPackage ./blueprint {};
  claude-desktop = pkgs.callPackage ./claude-desktop {};
  rofi-presets = pkgs.callPackage ./rofi-presets {};
  wallpaper-picker = pkgs.callPackage ./wallpaper-picker {};

  # Gaming
  proton-cachyos = pkgs.callPackage ./proton-cachyos {};
  wlcrosshair = pkgs.callPackage ./wlcrosshair {};

  # KDE/KWin - modular namespace
  kwin-scripts = import ./kwin-scripts pkgs;

  # Grafana plugins - modular namespace
  grafana-plugins = import ./grafana-plugins pkgs;

  # Themes - modular namespace with nested structure
  themes = import ./themes pkgs;
}
