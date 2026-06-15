{
  pkgs,
  lib,
  ...
}: let
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
      # I don't have issues that need this anymore. Kept in case I need it again.
      # toggle-internet = pkgs.writeShellApplication {
      #   name = "toggle-internet";
      #   text = builtins.readFile ./toggle-internet.sh;
      # };
      steam-download-wait = pkgs.writeShellApplication {
        name = "steam-download-wait";
        runtimeInputs = with pkgs; [coreutils gawk];
        text = builtins.readFile ./steam-download-wait.sh;
      };
      yubikey-enroll = pkgs.writeShellApplication {
        name = "yubikey-enroll";
        runtimeInputs = with pkgs; [pam_u2f coreutils];
        text = builtins.readFile ./yubikey-enroll.sh;
      };
    }
    // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
      open-port = pkgs.writeShellApplication {
        name = "open-port";
        runtimeInputs = with pkgs; [iptables];
        text = builtins.readFile ./open-port.sh;
      };
    };
in {
  home.packages = builtins.attrValues scripts;
}
