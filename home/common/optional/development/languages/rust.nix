{
  pkgs,
  inputs,
  lib,
  ...
}: {
  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Rust"];

  home.packages = with pkgs; [
    # Not rustup: it ships only shims, unusable until an imperative `rustup default`.
    (rust-bin.stable.latest.default.override {
      extensions = ["rust-src" "rust-analyzer"];
    })
    cargo-watch # Watch for changes and re-run cargo commands
    cargo-edit # Add/remove/upgrade dependencies from the CLI
    cargo-nextest # Faster test runner
    cargo-llvm-cov # Source-based code coverage via LLVM
    cargo-expand # Expand macros for debugging
    cargo-audit # Audit dependencies for security vulnerabilities
    cargo-flamegraph # Generate flamegraphs from cargo benchmarks
    bacon # Background code checker (like cargo-watch with a TUI)
  ];
}
