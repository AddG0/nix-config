{
  config,
  lib,
  ...
}: {
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
    ./dev-stacks.nix
  ];

  options.polyrepo.ghqRoot = lib.mkOption {
    type = lib.types.str;
    # ~/Projects matches xdg-user-dirs 0.20 (April 2026) XDG_PROJECTS_DIR; the
    # code/ subdir keeps ghq's host-namespaced clones separate from non-code
    # projects (3d-printing, etc).
    default = "${config.home.homeDirectory}/Projects/code";
    description = "On-disk root for ghq-managed clones; the anchor every polyrepo tool (ghq, gwq, scratch, dev stacks) builds paths from.";
  };
}
