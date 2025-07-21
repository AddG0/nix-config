{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Development tools
    unstable.claude-code
    repomix
  ];
}