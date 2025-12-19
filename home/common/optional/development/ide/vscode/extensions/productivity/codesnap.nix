{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.adpyke.codesnap
  ];
  userSettings = {
    "codesnap.backgroundColor" = "#abb8c3";
    "codesnap.boxShadow" = "rgba(0, 0, 0, 0.55) 0px 20px 68px";
    "codesnap.containerPadding" = "3em";
    "codesnap.roundedCorners" = true;
    "codesnap.showWindowControls" = true;
    "codesnap.showLineNumbers" = true;
    "codesnap.realLineNumbers" = false;
    "codesnap.transparentBackground" = false;
  };
}
