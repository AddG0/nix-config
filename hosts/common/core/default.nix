{
  pkgs,
  lib,
  config,
  inputs,
  self,
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
    ./${platform}
    ../users/primary
  ];

  #
  # ========== Core Host Specifications ==========
  #
  hostSpec = {
    username = lib.mkDefault "addg";
    handle = lib.mkDefault "addg";
    inherit isDarwin;

    system.stateVersion = lib.mkDefault "24.11";

    domain =
      if config.hostSpec.disableSops
      then lib.mkDefault "example.com"
      else inputs.nix-secrets.domain;

    email =
      if config.hostSpec.disableSops
      then
        lib.mkDefault {
          personal = "user@example.com";
          work = "user@work.example.com";
        }
      else inputs.nix-secrets.email;

    userFullName =
      if config.hostSpec.disableSops
      then lib.mkDefault "Example User"
      else inputs.nix-secrets.userFullName;

    githubEmail =
      if config.hostSpec.disableSops
      then lib.mkDefault "user@example.com"
      else inputs.nix-secrets.githubEmail;

    networking =
      if config.hostSpec.disableSops
      then
        lib.mkDefault {
          prefixLength = 24;
          ports.tcp.ssh = 22;
          ssh = {
            extraConfig = "";
          };
        }
      else inputs.nix-secrets.networking;
  };

  networking.hostName = config.hostSpec.hostName;
  nixpkgs.hostPlatform = config.hostSpec.hostPlatform;

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
      inherit inputs self;
    };
    backupFileExtension = "backup";
  };
}
