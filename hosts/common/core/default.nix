{
  pkgs,
  lib,
  config,
  inputs,
  outputs,
  isDarwin,
  ...
}: let
  platform =
    if isDarwin
    then "darwin"
    else "nixos";
  platformModules = "${platform}Modules";
in {
  imports = lib.flatten [
    inputs.home-manager.${platformModules}.home-manager
    inputs.sops-nix.${platformModules}.sops

    (lib.custom.scanPaths ./.)
    (map lib.custom.relativeToRoot [
      "modules/common"
      "modules/${platform}"
    ])
    ./${platform}
  ];

  #
  # ========== Core Host Specifications ==========
  #
  hostSpec = {
    username = "addg";
    handle = "addg";

    system.stateVersion = "24.11";

    inherit
      (inputs.nix-secrets) # TODO: Move to secrets.nix
      domain
      email
      userFullName
      githubEmail
      networking
      ;
  };

  networking.hostName = config.hostSpec.hostName;

  # This should be handled by config.security.pam.sshAgentAuth.enable
  security.sudo.extraConfig = ''
    Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
    Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
    Defaults timestamp_timeout=120 # only ask for password every 2h
    # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
    Defaults env_keep+=SSH_AUTH_SOCK
  '';

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs;
    };
    backupFileExtension = "backup";
  };
}
