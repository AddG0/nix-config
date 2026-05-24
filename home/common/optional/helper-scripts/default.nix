{pkgs, ...}: let
  scripts =
    {
      linktree = pkgs.writeShellApplication {
        name = "linktree";
        runtimeInputs = [];
        text = builtins.readFile ./linktree.sh;
      };
      kill-port = pkgs.writeShellApplication {
        name = "kill-port";
        runtimeInputs = with pkgs; [lsof];
        text = builtins.readFile ./kill-port.sh;
      };
      open-port = pkgs.writeShellApplication {
        name = "open-port";
        runtimeInputs = with pkgs; [iptables];
        text = builtins.readFile ./open-port.sh;
      };
      # I don't have issues that need this anymore. Kept in case I need it again.
      # toggle-internet = pkgs.writeShellApplication {
      #   name = "toggle-internet";
      #   text = builtins.readFile ./toggle-internet.sh;
      # };
      kill-cursor-rag = pkgs.writeShellApplication {
        name = "kill-cursor-rag";
        text = builtins.readFile ./kill-cursor-rag.sh;
      };
      gitlab-avatar = pkgs.writeShellApplication {
        name = "gitlab-avatar";
        runtimeInputs = with pkgs; [imagemagick];
        text = builtins.readFile ./gitlab-avatar.sh;
      };
      steam-download-wait = pkgs.writeShellApplication {
        name = "steam-download-wait";
        runtimeInputs = with pkgs; [coreutils gawk];
        text = builtins.readFile ./steam-download-wait.sh;
      };
      warm-flake-cache = pkgs.writeShellApplication {
        name = "warm-flake-cache";
        runtimeInputs = with pkgs; [nix-fast-build coreutils];
        text = builtins.readFile ./warm-flake-cache.sh;
      };
      yubikey-enroll = pkgs.writeShellApplication {
        name = "yubikey-enroll";
        runtimeInputs = with pkgs; [pam_u2f coreutils];
        text = builtins.readFile ./yubikey-enroll.sh;
      };
    }
    // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
      kill-cursor-rag = pkgs.writeShellApplication {
        name = "kill-cursor-rag";
        text = builtins.readFile ./kill-cursor-rag.sh;
      };
    };
in {
  home.packages = builtins.attrValues scripts;
}
