{
  pkgs,
  nix-secrets,
  config,
  ...
}: {
  imports = [
    "${nix-secrets}/modules/shipperhq"
  ];

  home.packages = with pkgs; [
    awscli2
    ssm-session-manager-plugin
  ];

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

  programs.zsh.oh-my-zsh.plugins = [
    "aws"
  ];

  home.sessionVariables = {
    AWS_PAGER = "bat --paging=always --language=json";
  };
}
