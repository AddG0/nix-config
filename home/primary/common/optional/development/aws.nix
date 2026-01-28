{
  nix-secrets,
  config,
  ...
}: {
  sops.secrets = {
    aws_credentials = {
      format = "binary";
      sopsFile = "${nix-secrets}/users/${config.hostSpec.username}/work/aws/credentials.enc";
      path = "${config.home.homeDirectory}/.aws/credentials";
    };
    aws_config = {
      format = "binary";
      sopsFile = "${nix-secrets}/users/${config.hostSpec.username}/work/aws/config.enc";
      path = "${config.home.homeDirectory}/.aws/config";
    };
  };
}
