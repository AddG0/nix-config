{
  nix-secrets,
  config,
  ...
}: {
  sops.secrets = {
    "buf/api_key" = {
      sopsFile = "${nix-secrets}/global/api-keys/buf.yaml";
    };
  };

  home.sessionVariables = {
    BUF_TOKEN = config.sops.secrets."buf/api_key".sopsFile;
  };
}
