{pkgs, ...}: let
  mainSource = ./modpacks/main-1.21.11;
  mainIcon = ../../../../../assets/avatars/addg-halloween.png;
in {
  programs.prismlauncher = {
    enable = true;
    modpacks = {
      "main-1.21.11" = {
        source = mainSource;
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
      };
      "main-1.21.11-smp" = {
        source = mainSource;
        excludeMods = ["tweakeroo" "tweakermore"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
        group = "SMP";
      };
    };
  };
}
