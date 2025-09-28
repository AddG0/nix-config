{
  pkgs,
  nix-secrets,
  config,
  lib,
  ...
}: {
  imports = [
    "${nix-secrets}/modules/shipperhq"
  ];

  home.packages = with pkgs; [
    awscli2
    ssm-session-manager-plugin

    # Saml2aws
    saml2aws
  ];

  sops.secrets = {
    aws_credentials = {
      format = "binary";
      sopsFile = "${nix-secrets}/secrets/shipperhq/aws-credentials.enc";
      path = "${config.home.homeDirectory}/.aws/credentials";
    };
    aws_config = {
      format = "binary";
      sopsFile = "${nix-secrets}/secrets/shipperhq/aws-config.enc";
      path = "${config.home.homeDirectory}/.aws/config";
    };
  };

  programs.zsh.oh-my-zsh.plugins = [
    "aws"
  ];

  home.sessionVariables = {
    AWS_PAGER = "bat --paging=always --language=json";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
  };
}
