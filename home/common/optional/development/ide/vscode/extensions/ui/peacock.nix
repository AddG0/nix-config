{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.johnpapa.vscode-peacock
  ];
  userSettings = {
    "peacock.favoriteColors" = [
      {
        "name" = "Angular Red";
        "value" = "#dd0531";
      }
      {
        "name" = "Vue Green";
        "value" = "#42b883";
      }
      {
        "name" = "React Blue";
        "value" = "#61dafb";
      }
      {
        "name" = "Nix Blue";
        "value" = "#5277c3";
      }
      {
        "name" = "Node Green";
        "value" = "#215732";
      }
      {
        "name" = "Python Yellow";
        "value" = "#ffde57";
      }
      {
        "name" = "Rust Orange";
        "value" = "#ce422b";
      }
      {
        "name" = "Go Cyan";
        "value" = "#00add8";
      }
    ];
    "peacock.affectActivityBar" = true;
    "peacock.affectStatusBar" = true;
    "peacock.affectTitleBar" = true;
  };
}
