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
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "${config.home.homeDirectory}/.1password/agent.sock";
in {
  # Configure SSH to use 1Password as the SSH agent
  # mkBefore ensures this is added before other extraConfig settings
  programs.ssh.extraConfig = lib.mkBefore ''
    IdentityAgent "${agentPath}"
  '';

  # Disable the traditional SSH agent plugin
  programs.ssh.enableTraditionalAgent = false;

  # Set SSH_AUTH_SOCK to 1Password's agent socket, but only for local sessions
  # (preserve forwarded agent when SSH'd in with -A)
  programs.zsh.initContent = lib.mkBefore ''
    if [[ -z "$SSH_CONNECTION" ]]; then
      export SSH_AUTH_SOCK="${agentPath}"
    fi
  '';
}
