# codeq: one command for code-quality metrics across languages; `codeq` lists them.
# Build tools (gradle, mvn, go) come from the project's own shell, not from here.
{
  pkgs,
  customPkgs,
  ...
}: {
  home.packages = [(pkgs.callPackage ./package.nix {inherit customPkgs;})];
  programs.git.ignores = [".codeq/"];
}
