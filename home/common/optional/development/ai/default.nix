{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./claude-code
  ];

  home.packages = with pkgs;
    [
      # Development tools
      claude-code-router
      # claude-flow
      repomix
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      claude-desktop
    ];
}
