{pkgs, ...}: {
  home.packages = with pkgs; [
    rustup # Rust toolchain installer (rustc, cargo, rustfmt, clippy)
    cargo-watch # Watch for changes and re-run cargo commands
    cargo-edit # Add/remove/upgrade dependencies from the CLI
    cargo-nextest # Faster test runner
    cargo-expand # Expand macros for debugging
    cargo-audit # Audit dependencies for security vulnerabilities
    cargo-flamegraph # Generate flamegraphs from cargo benchmarks
    bacon # Background code checker (like cargo-watch with a TUI)
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "rust"
  ];
}
