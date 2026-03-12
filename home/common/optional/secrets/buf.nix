{
  inputs,
  config,
  ...
}: {
  sops.secrets = {
    "buf/api_key" = {
      sopsFile = "${inputs.nix-secrets}/global/api-keys/buf.yaml";
    };
  };

  home.sessionVariables = {
    BUF_TOKEN = config.sops.secrets."buf/api_key".sopsFile;
  };
}
