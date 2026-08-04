{
  config,
  lib,
  pkgs,
  ...
}: let
  mainSource = ./modpacks/main-1.21.11;
  mainIcon = ../../../../../assets/avatars/addg-halloween.png;
  # Offload to the dGPU only on hybrid hosts
  useDiscreteGpu = config.hostSpec.gpu.offload != null;
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
        inherit useDiscreteGpu;
      };
      "main-1.21.11-smp" = {
        source = mainSource;
        excludeMods = ["tweakeroo" "tweakermore" "herobot"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
        inherit useDiscreteGpu;
        group = "SMP";
        servers = [
          {
            name = "mcpvp.club";
            address = "mcpvp.club";
          }
          {
            name = "Hypixel";
            address = "mc.hypixel.net";
          }
        ];
      };
      # World save: https://shelledturtle.gumroad.com/l/TheosPVPPractice
      "main-1.21.11-pvp-practice" = {
        source = mainSource;
        excludeMods = ["carpet" "carpet-extra" "carpet-tis-addition" "carpet-pvp"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
        inherit useDiscreteGpu;
      };
    };
  };

  # Prism instances map as XWayland class "Minecraft* <version>" (* = modded).
  # mkBefore so the tag precedes the tag:game consumers in other modules.
  wayland.windowManager.hyprland.settings.windowrule = lib.mkBefore [
    "tag +game, match:class ^(Minecraft\\*? .*)$"
  ];
}
