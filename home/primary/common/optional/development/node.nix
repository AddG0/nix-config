{pkgs, ...}: {
  home.packages =
    (with pkgs; [
      nodejs_22
      jetbrains.webstorm
    ])
    ++ (with pkgs.nodePackages; [
      yarn
      typescript
      typescript-language-server
    ]);
}
