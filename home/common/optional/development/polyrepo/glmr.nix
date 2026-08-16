{
  config,
  lib,
  pkgs,
  ...
}: let
  # Opens a GitLab MR for review in nvim. Only needs ghq (path resolution) and
  # ghostty (to open the terminal); the terminal runs a login shell, so
  # gwadd/ghq/nvim resolve from the interactive PATH.
  glmr-open = pkgs.writeShellApplication {
    name = "glmr-open";
    runtimeInputs = [pkgs.ghq pkgs.ghostty pkgs.bash pkgs.coreutils pkgs.yad];
    text = builtins.readFile ./scripts/glmr-open.sh;
  };
in
  lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.hostSpec.hostType != "server") {
    home.packages = [glmr-open];

    # glmr://open?host=…&project=…&iid=…&branch=… — open that MR's review in nvim.
    xdg.desktopEntries.glmr-open = {
      name = "Open GitLab MR in Neovim";
      genericName = "Merge request review";
      comment = "Open a GitLab merge request in a gwq worktree and start the gitlab.nvim review";
      exec = "${glmr-open}/bin/glmr-open %u";
      terminal = false;
      noDisplay = true;
      categories = ["Development"];
      mimeType = ["x-scheme-handler/glmr"];
    };

    xdg.mimeApps.defaultApplications."x-scheme-handler/glmr" = ["glmr-open.desktop"];
  }
