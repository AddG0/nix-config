{pkgs, ...}: {
  # Keybinds (CTRL-G prefix):
  #   CTRL-G CTRL-F — files
  #   CTRL-G CTRL-B — branches
  #   CTRL-G CTRL-T — tags
  #   CTRL-G CTRL-R — remotes
  #   CTRL-G CTRL-H — hashes (commits)
  #   CTRL-G CTRL-S — stashes
  #   CTRL-G CTRL-L — reflogs
  #   CTRL-G CTRL-W — worktrees
  #   CTRL-G CTRL-E — each ref (for-each-ref)
  home.packages = [pkgs.fzf-git-sh];

  programs.zsh.initContent = ''
    source ${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh
  '';
}
