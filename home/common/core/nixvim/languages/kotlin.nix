{pkgs, ...}: {
  # Official JetBrains Kotlin LSP (pkgs/kotlin-lsp, our custom package) instead
  # of the flaky/unmaintained fwcd kotlin-language-server. nixvim has the
  # lspconfig `kotlin_lsp` preset; we point cmd at our packaged launcher in
  # stdio mode. Needs a Gradle/Maven project (opened from its root) to resolve
  # dependencies — it indexes on first attach.
  plugins.lsp.servers.kotlin_lsp = {
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

  # Test runner: neotest-gradle (framework: ../testing.nix). kotlin_lsp has no
  # test-running support of its own, and its treesitter parser ("kotlin,java")
  # covers gradle Java tests too — whereas pure Java projects run through
  # nvim-jdtls' java-test bundle in ./java.nix, so the two don't overlap.
  plugins.neotest.adapters.gradle.enable = true;
}
