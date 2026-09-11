# Serve my keys from the 1Password agent instead of a local ssh-agent. Only
# the workstations holding the vault import this; everywhere else the same keys
# arrive over a forwarded agent, which needs no config of its own.
#
# Needs, outside of nix: the 1Password GUI (hosts/common/optional/1password.nix),
# Settings → Developer → "Use the SSH Agent" enabled, and the keys in the vault.
{
  config,
  lib,
  pkgs,
  ...
}: let
  agentPath =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "${config.home.homeDirectory}/.1password/agent.sock";
in {
  programs.ssh = {
    includes = ["~/.ssh/1Password/config"];

    # tmux does not propagate SSH_TTY, so panes look local — and IdentityAgent
    # would then override their forwarded SSH_AUTH_SOCK. The link is persistent,
    # so match on its value, not its existence.
    settings."1password-agent" = {
      # Stable attr name for ordering; the literal Match header carries the
      # actual condition.
      header = ''Match host * exec "test -z $SSH_TTY && test x$SSH_AUTH_SOCK != x$HOME/.ssh/ssh_auth_sock"'';
      IdentityAgent = ''"${agentPath}"'';
    };

    enableTraditionalAgent = false;
  };

  # Local sessions only, so an SSH'd-in shell keeps its forwarded agent;
  # inside tmux, ssh.nix owns SSH_AUTH_SOCK.
  programs.zsh.initContent = lib.mkBefore ''
    if [[ -z "$SSH_CONNECTION" && -z "$TMUX" ]]; then
      export SSH_AUTH_SOCK="${agentPath}"
    fi
  '';
}
