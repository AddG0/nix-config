# snacks.nvim explorer fixes — each adds behavior snacks lacks natively; drop a
# file once upstream ships the equivalent option.
_: {
  imports = [
    ./explorer-compact-packages.nix
    ./explorer-expand-collapse.nix
    ./explorer-git-refresh.nix
    ./explorer-nesting.nix
  ];
}
