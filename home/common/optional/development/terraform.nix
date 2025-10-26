{pkgs, ...}: {
  home.packages = with pkgs; [
    terraform
    opentofu
    terragrunt
  ];

  home.shellAliases = {
    tf = "terraform";
    tg = "terragrunt";
  };
}
