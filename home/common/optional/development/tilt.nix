{pkgs, ...}: let
  tilt-completions = pkgs.runCommand "tilt-completions" {} ''
    mkdir -p $out/share/zsh/site-functions
    mkdir -p $out/share/bash-completion/completions
    ${pkgs.tilt}/bin/tilt completion zsh > $out/share/zsh/site-functions/_tilt
    ${pkgs.tilt}/bin/tilt completion bash > $out/share/bash-completion/completions/tilt
  '';
in {
  home.packages = with pkgs; [
    tilt
    tilt-completions
  ];
}
