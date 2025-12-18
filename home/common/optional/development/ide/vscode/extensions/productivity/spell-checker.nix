{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.streetsidesoftware.code-spell-checker
  ];
  userSettings = {
    # Disable for nix files - too many false positives
    "cSpell.enableFiletypes" = [
      "!nix"
    ];
    # Show as hints instead of problems
    "cSpell.diagnosticLevel" = "Hint";
  };
}
