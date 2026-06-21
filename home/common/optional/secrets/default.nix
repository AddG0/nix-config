{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.primaryUsername}/personal.yaml";
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops-nix/age/keys.txt";
      generateKey = true;
    };

    secrets."personal_accounts/github_personal_token" = {};

    templates."nix-access-tokens.conf".content = ''
      access-tokens = github.com=${config.sops.placeholder."personal_accounts/github_personal_token"}
    '';
  };

  # interactive `nix` runs as this user; pull the token in via the sops-rendered fragment
  nix.extraOptions = ''
    !include ${config.sops.templates."nix-access-tokens.conf".path}
  '';

  home.packages = with pkgs; [
    sops
    age
  ];

  programs.zsh.initContent = ''
    export GITHUB_TOKEN=$(cat ${config.sops.secrets."personal_accounts/github_personal_token".path})
    export SOPS_AGE_KEY_FILE=~/.config/sops-nix/age/keys.txt
  '';

  # This is so I can use sops in the shell anywhere
  home.file.".sops.yaml" = {
    source = ./.sops.yaml;
  };
}
