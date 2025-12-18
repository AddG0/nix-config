{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.mhutchie.git-graph
  ];
  userSettings = {
    "git-graph.defaultColumnVisibility" = {
      "Date" = true;
      "Author" = true;
      "Commit" = true;
    };
    "git-graph.graph.style" = "rounded";
  };
}
