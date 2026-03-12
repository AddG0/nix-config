{
  config,
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    cachix
  ];

  sops.secrets = {
    "cachix/auth_token" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/development.yaml";
    };
  };

  programs.zsh.initContent = ''
    export CACHIX_AUTH_TOKEN=$(cat ${config.sops.secrets."cachix/auth_token".path})
  '';
}
