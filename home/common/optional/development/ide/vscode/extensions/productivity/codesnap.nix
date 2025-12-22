{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.adpyke.codesnap
  ];
  userSettings = {
    # Ray.so "Breeze" theme - pink to purple gradient
    "codesnap.backgroundColor" = "linear-gradient(140deg, #cf2f98 0%, #6a3dec 100%)";
    "codesnap.boxShadow" = "rgba(0, 0, 0, 0.4) 0px 16px 48px";
    "codesnap.containerPadding" = "3em";
    "codesnap.roundedCorners" = true;
    "codesnap.showWindowControls" = true;
    "codesnap.showWindowTitle" = false;
    "codesnap.showLineNumbers" = true;
    "codesnap.realLineNumbers" = false;
    "codesnap.transparentBackground" = false;
  };
}
