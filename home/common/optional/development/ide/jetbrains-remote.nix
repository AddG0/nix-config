{pkgs, ...}: {
  programs.jetbrains-remote = {
    enable = true;
    ides = with pkgs.jetbrains; [idea];
  };
}
