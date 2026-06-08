{
  inputs,
  config,
  ...
}: {
  sops.secrets = {
    aws_credentials = {
      format = "binary";
      sopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.primaryUsername}/work/aws/credentials.enc";
      path = "${config.home.homeDirectory}/.aws/credentials";
    };
    aws_config = {
      format = "binary";
      sopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.primaryUsername}/work/aws/config.enc";
      path = "${config.home.homeDirectory}/.aws/config";
    };
  };
}
