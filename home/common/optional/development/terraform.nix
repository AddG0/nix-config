{pkgs, ...}: {
  home.packages = with pkgs; [
    terraform
    opentofu
    terragrunt
    terramate
  ];

  home.shellAliases = {
    tf = "terraform";
    tg = "terragrunt";
    tm = "terramate";
  };
}
