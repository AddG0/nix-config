{pkgs, ...}: let
  # terramate ships no completion script and is a `complete -C` self-completer
  # (kong/kongplete); package a zsh shim onto fpath instead of editing ~/.zshrc.
  terramate-completions = pkgs.runCommand "terramate-completions" {} ''
    mkdir -p $out/share/zsh/site-functions
    printf '#compdef terramate\nautoload -U +X bashcompinit && bashcompinit\ncomplete -o nospace -C %s terramate\n' \
      ${pkgs.terramate}/bin/terramate > $out/share/zsh/site-functions/_terramate
  '';
in {
  home.packages = with pkgs; [
    terraform
    opentofu
    terragrunt
    terramate
    terramate-completions
  ];

  home.shellAliases = {
    tf = "terraform";
    tg = "terragrunt";
    tm = "terramate";
  };

  programs.zsh.oh-my-zsh.plugins = [
    "terraform"
  ];
}
