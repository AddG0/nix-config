{pkgs, ...}: let
  # git-aware rsync: excludes .git and respects .gitignore / .git/info/exclude.
  # Pulled out of `scripts` so ghq-sync below can take it as a runtimeInput.
  gsync = pkgs.writeShellApplication {
    name = "gsync";
    runtimeInputs = with pkgs; [git rsync gnused coreutils];
    text = builtins.readFile ./gsync.sh;
  };

  scripts = {
    # Run a command and get a desktop notification when it finishes.
    # Linux uses notify-send (libnotify); macOS uses terminal-notifier.
    notify = pkgs.writeShellApplication {
      name = "notify";
      runtimeInputs =
        if pkgs.stdenv.isDarwin
        then [pkgs.terminal-notifier]
        else [pkgs.libnotify];
      text = builtins.readFile ./notify.sh;
    };
    # Pre-build devShells of one or more flake repos into the nix store.
    warm-flake-cache = pkgs.writeShellApplication {
      name = "warm-flake-cache";
      runtimeInputs = with pkgs; [nix-fast-build coreutils];
      text = builtins.readFile ./warm-flake-cache.sh;
    };
    # Optimize an image for GitLab group/project avatars (192x192, max 200 KiB).
    gitlab-avatar = pkgs.writeShellApplication {
      name = "gitlab-avatar";
      runtimeInputs = with pkgs; [imagemagick];
      text = builtins.readFile ./gitlab-avatar.sh;
    };
    # Run any dev command with OpenTelemetry auto-instrumentation, pointed at the
    # local collector (Node + JVM + Python). See ./otel-dev for the Nix details.
    otel-dev = pkgs.callPackage ./otel-dev {};
    inherit gsync;
    # Push the ghq repo you're in to the same path on another computer, via
    # gsync. Lives here (not ghq.nix) so it can depend on the gsync package.
    ghq-sync = pkgs.writeShellApplication {
      name = "ghq-sync";
      runtimeInputs = [gsync pkgs.ghq pkgs.git];
      text = builtins.readFile ./ghq-sync.sh;
    };
  };
in {
  home.packages = builtins.attrValues scripts;
}
