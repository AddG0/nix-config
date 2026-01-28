{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    awscli2
    ssm-session-manager-plugin
  ];

  programs.zsh.oh-my-zsh.plugins = [
    "aws"
  ];

  home.sessionVariables = {
    AWS_PAGER = "bat --paging=always --language=json";
  };
}
