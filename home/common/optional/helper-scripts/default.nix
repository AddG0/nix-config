{pkgs, ...}: let
  scripts =
    {
      linktree = pkgs.writeShellApplication {
        name = "linktree";
        runtimeInputs = [];
        text = builtins.readFile ./linktree.sh;
      };
      close-port = pkgs.writeShellApplication {
        name = "close-port";
        runtimeInputs = with pkgs; [lsof];
        text = builtins.readFile ./close-port.sh;
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
