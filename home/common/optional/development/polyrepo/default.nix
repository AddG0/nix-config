{
  config,
  lib,
  ...
}: {
  # Polyrepo dev flow:
  #   ghq      clone management + on-disk layout (~/Projects/code/...)
  #   gwq      worktrees, sibling to clones, --branch suffix
  #   mani     manifest + tag-based bulk git ops
  #   sesh     tmux session picker over multiple sources (Prefix+T)
  #   scratch  throwaway git-init'd projects under ghq's tree (Alt-G picks)
  #   glmr     glmr:// URI handler → open a GitLab MR for review in nvim
  imports = [
    ./ghq.nix
    ./gwq.nix
    ./mani.nix
    ./scratch.nix
    ./sesh.nix
    ./dev-stacks.nix
    ./glmr.nix
  ];

  options.polyrepo = {
    ghqRoot = lib.mkOption {
      type = lib.types.str;
      # ~/Projects matches xdg-user-dirs 0.20 (April 2026) XDG_PROJECTS_DIR; the
      # code/ subdir keeps ghq's host-namespaced clones separate from non-code
      # projects (3d-printing, etc).
      default = "${config.home.homeDirectory}/Projects/code";
      description = "On-disk root for ghq-managed clones; the anchor every polyrepo tool (ghq, gwq, scratch, dev stacks) builds paths from.";
    };

    extraSearchRoots = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Root to scan.";
          };

          depth = lib.mkOption {
            type = lib.types.ints.positive;
            default = 1;
            description = "How many levels below `path` a checkout sits. ghq's own clones are 3 (host/owner/repo).";
          };

          label = lib.mkOption {
            type = lib.types.str;
            description = "Prefix the picker shows, keeping these entries apart from ghq's.";
          };
        };
      });
      default = [];
      description = ''
        Checkout roots outside the ghq tree for the Alt-G picker to include, for
        tools that own their own layout. Set from the module that owns the
        directory, so the path stays declared in one place.
      '';
    };
  };
}
