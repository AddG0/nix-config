{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.theqtcompany.qt-core
    pkgs.vscode-marketplace.theqtcompany.qt-qml
  ];
  userSettings = {
    # Point qmlls at the binary from qtdeclarative in the nix store.
    "qt-qml.qmlls.customExePath" = "${pkgs.qt6.qtdeclarative}/bin/qmlls";
    # Suppress the "Install the QML language server?" prompt — we've
    # already wired our own path above.
    "qt-qml.doNotAskForQmllsDownload" = true;
    # qt-core's kit-finder wizards are irrelevant when only editing QML.
    "qt-core.doNotAskForDefaultQtInstallationRoot" = true;
    "qt-core.doNotAskForVCPKG" = true;

    # Open .qrc files in qt-core's qrcEditor by default, but keep the
    # plain-text editor when viewing them through git history / diffs
    # (gitlens scheme etc.) so blame/diff stays readable.
    "workbench.editorAssociations" = {
      "*.qrc" = "qt-core.qrcEditor";
      "{git,gitlens,chat-editing-snapshot-text-model,copilot,git-graph,git-graph-3}:/**/*.qrc" = "default";
    };
  };
}
