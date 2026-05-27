_: {
  # Polyrepo dev flow:
  #   ghq      clone management + on-disk layout (~/Projects/code/...)
  #   gwq      worktrees, sibling to clones, =branch suffix
  #   mani     manifest + tag-based bulk git ops
  #   sesh     tmux session picker over multiple sources (Prefix+T)
  #   scratch  throwaway git-init'd projects under ghq's tree (Alt-G picks)
  imports = [
    ./ghq.nix
    ./gwq.nix
    ./mani.nix
    ./scratch.nix
    ./sesh.nix
  ];
}
