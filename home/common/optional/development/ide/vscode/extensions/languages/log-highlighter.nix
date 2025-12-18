{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.emilast.logfilehighlighter
  ];
  userSettings = {
    "logFileHighlighter.customPatterns" = [
      {
        "pattern" = "ERROR";
        "foreground" = "#ff0000";
        "fontWeight" = "bold";
      }
      {
        "pattern" = "WARN";
        "foreground" = "#ffa500";
      }
      {
        "pattern" = "INFO";
        "foreground" = "#00ff00";
      }
      {
        "pattern" = "DEBUG";
        "foreground" = "#808080";
      }
    ];
  };
}
