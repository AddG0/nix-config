{optional, ...}: {
  ide.home = with optional.home.development.ide; [jetbrains vscode];
}
