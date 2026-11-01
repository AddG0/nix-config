# Suites over the REAL tmux-ssh-auth-sock-link script: logic against a stub
# tmux, behaviour against a live one, and the zsh ordering it relies on. Routing
# through the rendered ssh config is in ./_credentials.nix.
{
  harness,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs) writeShellScriptBin coreutils python3 tmux util-linux gnugrep gawk ncurses zsh;
  testLib = self.lib.extend (_: _: {inherit (self.inputs.home-manager.lib) hm;});
  sshConfig =
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      lib = testLib;
      extraSpecialArgs = {
        inherit self;
        hostSpec = {
          primaryUsername = "tester";
          home = "/home/tester";
          system.stateVersion = "24.05";
        };
      };
      modules = [
        {
          home = {
            username = "tester";
            homeDirectory = "/home/tester";
            stateVersion = "24.05";
          };
        }
        {programs.zsh.oh-my-zsh.enable = true;}
        ../default.nix
      ];
    }).config;

  script = pkgs.callPackage ../agent-link.nix {};
  # Stand-in for tmux; ./link.bats documents what it answers.
  stub = writeShellScriptBin "tmux-stub" ''
    case "$1" in
      list-clients)
        # -F '#{client_name}' asks for names only; anything else wants both.
        if [ "$*" = "list-clients -F #{client_name}" ]; then
          cut -d' ' -f2- "$CLIENTS" 2>/dev/null || true
        else
          cat "$CLIENTS" 2>/dev/null || true
        fi
        ;;
      show-environment)
        if [ -n "''${SESSION_SOCK:-}" ]; then echo "SSH_AUTH_SOCK=$SESSION_SOCK"; fi
        ;;
      set-environment)
        shift
        echo "$*" >>"$SETENV_LOG"
        ;;
    esac
  '';
  credentials = import ./_credentials.nix {inherit harness pkgs lib self;};
in
  harness.bats "tmux-ssh-auth-sock-link-tests" [./link.bats ./link-tmux.bats ./zshrc.bats] {
    nativeBuildInputs = [coreutils gnugrep gawk python3 tmux util-linux ncurses zsh];
    linkScript = "${script}/bin/tmux-ssh-auth-sock-link";
    tmuxStub = "${stub}/bin/tmux-stub";
    hooks = pkgs.writeText "hooks.conf" (import ../hooks.nix "${script}/bin/tmux-ssh-auth-sock-link");
    zshrc = pkgs.writeText "zshrc" sshConfig.programs.zsh.initContent;
    inherit (credentials) onePasswordZshrc onePasswordAgent routing sessionAgent;
  }
