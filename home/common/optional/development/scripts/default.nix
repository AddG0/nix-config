{pkgs, ...}: let
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
  };
in {
  home.packages = builtins.attrValues scripts;
}
