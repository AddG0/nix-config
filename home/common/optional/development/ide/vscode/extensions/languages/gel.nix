{pkgs, ...}: {
  extensions = [
    # Official Gel extension - EdgeQL/Gel SDL syntax highlighting, snippets, embedded query strings
    pkgs.vscode-marketplace.magicstack.edgedb
  ];
}
