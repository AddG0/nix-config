{
  pkgs,
  inputs,
  lib,
  ...
}: {
  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Node"];

  home.packages = with pkgs; [
    nodejs_24
    pnpm
    bun
    yarn
    typescript
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "node"
    "npm"
    "yarn"
  ];
}
