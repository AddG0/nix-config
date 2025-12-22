{
  config,
  lib,
  ...
}: let
  gitSettings = config.programs.git.settings;

  # Parse trim.bases (e.g., "develop,master,main") into a list for branch protection
  branchProtection = lib.splitString "," (gitSettings.trim.bases or "main,master");

  # Convert git's "true"/"false" string to boolean
  useRebase = (gitSettings.pull.rebase or "false") == "true";
in {
  # Base VSCode Git settings (no extension needed)
  userSettings = {
    # Smart commit - stage all changes when no staged changes
    "git.enableSmartCommit" = true;

    # Auto fetch
    "git.autofetch" = true;
    "git.autofetchPeriod" = 180;

    # Confirm actions
    "git.confirmSync" = false;
    "git.confirmEmptyCommits" = false;

    # Default branch name (from programs.git config)
    "git.defaultBranchName" = gitSettings.init.defaultBranch;

    # Prune on fetch
    "git.pruneOnFetch" = true;

    # Pull with rebase (from programs.git config)
    "git.rebaseWhenSync" = useRebase;

    # Auto stash before pull/checkout
    "git.autoStash" = true;

    # Pull tags automatically
    "git.pullTags" = true;

    # Open repo after clone
    "git.openAfterClone" = "always";

    # Branch protection (from trim.bases in programs.git config)
    "git.branchProtection" = branchProtection;
    "git.branchProtectionPrompt" = "alwaysPrompt";

    # Use terminal for auth (for SSH keys)
    "git.terminalAuthentication" = true;

    # Don't prompt to open repos found in parent folders
    "git.openRepositoryInParentFolders" = "never";
  };
}
