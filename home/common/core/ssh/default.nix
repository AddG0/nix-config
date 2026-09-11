{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.ssh;

  sshAuthSockLink = "${pkgs.callPackage ./agent-link.nix {}}/bin/tmux-ssh-auth-sock-link";
in {
  options.programs.ssh.enableTraditionalAgent = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to enable the traditional SSH agent via oh-my-zsh plugin.
      Set to false when using alternative SSH agents like 1Password.
    '';
  };

  config = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      extraConfig = ''
        AddKeysToAgent yes
      '';

      # Transport mechanics; which of *my* keys a host may use is per-user
      # policy (mine: home/primary/common/core/ssh.nix).
      settings."*" = {
        ControlMaster = "auto";
        # %n (alias as typed) instead of %h (resolved hostname) so two
        # match blocks that share HostName get distinct mux sockets.
        ControlPath = "~/.ssh/sockets/S.%r@%n:%p";
        ControlPersist = "10m";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        TCPKeepAlive = "yes";
        # Without a forwarded locale, remote tmux runs non-UTF-8 and mangles glyphs.
        SendEnv = ["LANG" "LC_*"];
      };
    };

    programs.zsh.oh-my-zsh.plugins =
      lib.optional cfg.enableTraditionalAgent "ssh-agent"
      ++ ["ssh"];

    # Enable agent-forwarding before oh-my-zsh loads (respects forwarded agents)
    programs.zsh.oh-my-zsh.extraConfig = lib.mkIf cfg.enableTraditionalAgent ''
      zstyle :omz:plugins:ssh-agent agent-forwarding yes
    '';

    # programs.tmux.extraConfig merges with the core tmux module.
    # update-environment refreshes the session env before client-attached fires.
    programs.tmux.extraConfig = import ./hooks.nix sshAuthSockLink;

    programs.zsh.initContent = lib.mkMerge [
      # Drop a dead inherited socket so the agent plugin below starts a local one.
      (lib.mkBefore ''
        if [[ -n "$TMUX" && -n "$SSH_AUTH_SOCK" && ! -S "$SSH_AUTH_SOCK" ]]; then
          unset SSH_AUTH_SOCK
        fi
      '')
      # mkAfter so a locally started agent is what gets linked when none was forwarded.
      # Exported even while dangling: the next attach repairs a symlink, not a baked-in path.
      (lib.mkAfter ''
        if [[ -n "$TMUX" ]]; then
          if [[ ! -S "$HOME/.ssh/ssh_auth_sock" && -S "$SSH_AUTH_SOCK" ]]; then
            ln -sfn "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
          fi
          export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
        fi
      '')
    ];

    # Ensures ~/.ssh/sockets/ exists before ssh tries to bind a ControlMaster socket there.
    home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
  };
}
