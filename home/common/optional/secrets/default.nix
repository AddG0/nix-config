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
    defaultSopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.username}/personal.yaml";
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops-nix/age/keys.txt";
      generateKey = true;
    };
  };

  sops.secrets = {
    "personal_accounts/github_personal_token" = {};
  };

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
