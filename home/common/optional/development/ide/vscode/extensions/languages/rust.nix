{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.rust-lang.rust-analyzer
    pkgs.vscode-marketplace.tamasfe.even-better-toml
    pkgs.vscode-extensions.vadimcn.vscode-lldb
  ];
  userSettings = {
    "rust-analyzer.check.command" = "clippy";
    "rust-analyzer.inlayHints.chainingHints.enable" = true;
    "rust-analyzer.inlayHints.typeHints.enable" = true;
    "rust-analyzer.inlayHints.parameterHints.enable" = true;
    "rust-analyzer.lens.enable" = true;
  };
}
