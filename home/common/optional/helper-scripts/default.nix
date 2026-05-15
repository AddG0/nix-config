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
      toggle-internet = pkgs.writeShellApplication {
        name = "toggle-internet";
        text = builtins.readFile ./toggle-internet.sh;
      };
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
