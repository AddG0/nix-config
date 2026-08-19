# 1Password SSH Agent Integration
#
# This module configures SSH to use 1Password's SSH agent instead of the traditional ssh-agent.
#
# Prerequisites:
#   1. 1Password GUI must be installed (via hosts/common/optional/1password.nix)
#   2. In 1Password app: Settings → Developer → Enable "Use the SSH Agent"
#   3. SSH keys must be stored in 1Password (can import existing keys)
#
# Usage:
#   Import this module in your home-manager configuration:
#
#   # home/primary/<hostname>.nix
#   imports = [
#     "secrets/1password-ssh.nix"
#   ];
#
# How it works:
#   - Sets IdentityAgent to 1Password's SSH agent socket
#   - Removes the traditional ssh-agent oh-my-zsh plugin (conflicts with 1Password)
#   - Keeps all existing IdentityFile settings (SSH still needs public key paths)
#   - Works alongside existing SSH match blocks and configurations
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Platform-specific socket paths for 1Password SSH agent
  agentPath =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "${config.home.homeDirectory}/.1password/agent.sock";
in {
  programs.ssh = {
    # Include 1Password's generated per-key config.
    includes = ["~/.ssh/1Password/config"];

    # tmux does not propagate SSH_TTY, so panes look local — and IdentityAgent
    # would then override their forwarded SSH_AUTH_SOCK.
    settings."1password-agent" = {
      # Stable attr name for ordering; the literal Match header carries the
      # actual condition.
      header = ''Match host * exec "test -z $SSH_TTY && ! test -S $HOME/.ssh/ssh_auth_sock"'';
      IdentityAgent = ''"${agentPath}"'';
    };

    # Disable the traditional SSH agent plugin
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
