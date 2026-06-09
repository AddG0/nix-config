{pkgs, ...}: {
  # Official JetBrains Kotlin LSP (pkgs/kotlin-lsp, our custom package) instead
  # of the flaky/unmaintained fwcd kotlin-language-server. nixvim has the
  # lspconfig `kotlin_lsp` preset; we point cmd at our packaged launcher in
  # stdio mode. Needs a Gradle/Maven project (opened from its root) to resolve
  # dependencies — it indexes on first attach.
  programs.nixvim.plugins.lsp.servers.kotlin_lsp = {
    enable = true;
    package = pkgs.kotlin-lsp;
    cmd = ["${pkgs.kotlin-lsp}/bin/kotlin-lsp" "--stdio"];
    filetypes = ["kotlin"];
    rootMarkers = [
      "settings.gradle"
      "settings.gradle.kts"
      "build.gradle"
      "build.gradle.kts"
      "pom.xml"
      ".git"
    ];
  };
}
