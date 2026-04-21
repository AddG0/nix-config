{pkgs, ...}: let
  mainSource = ./modpacks/main-1.21.11;
  mainIcon = ../../../../../assets/avatars/addg-halloween.png;
in {
  programs.prismlauncher = {
    enable = true;
    modpacks = {
      "main-1.21.11" = {
        source = mainSource;
        excludeMods = ["herobot"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
      };
      "main-1.21.11-smp" = {
        source = mainSource;
        excludeMods = ["tweakeroo" "tweakermore" "herobot"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
        group = "SMP";
      };
      # World save: https://shelledturtle.gumroad.com/l/TheosPVPPractice
      "main-1.21.11-pvp-practice" = {
        source = mainSource;
        excludeMods = ["carpet" "carpet-extra" "carpet-tis-addition" "carpet-pvp"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
      };
    };
  };
}
