{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    cachix
  ];

  sops.secrets = {
    cachix_auth_token = {};
  };

  programs.zsh.initContent = ''
    export CACHIX_AUTH_TOKEN=$(cat ${config.sops.secrets.cachix_auth_token.path})
  '';
}
