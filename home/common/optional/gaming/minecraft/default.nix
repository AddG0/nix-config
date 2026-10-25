{
  config,
  lib,
  pkgs,
  ...
}: let
  mainSource = ./modpacks/main-1.21.11;
  mainIcon = ../../../../../assets/avatars/addg-halloween.png;
  # Heap in MiB; Prism defaults to 512/4096, too small for this pack
  minMemory = 2048;
  maxMemory = lib.mkDefault 8192;
  # Offload to the dGPU only on hybrid hosts
  useDiscreteGpu = config.hostSpec.gpu.offload != null;
in {
  imports = [../_window-classes.nix];

  programs.prismlauncher = {
    enable = true;
    onPrismRunning = "close";
    # The Safe Eyes game guard watches gamemoded, so cover unmanaged instances too
    settings.EnableFeralGamemode = true;
    modpacks = {
      "main-1.21.11" = {
        source = mainSource;
        excludeMods = ["herobot"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
        inherit useDiscreteGpu minMemory maxMemory;
      };
      "main-1.21.11-smp" = {
        source = mainSource;
        excludeMods = ["tweakeroo" "tweakermore" "herobot"];
        icon = mainIcon;
        javaPackage = pkgs.jdk25;
        enableGameMode = true;
        inherit useDiscreteGpu minMemory maxMemory;
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
        inherit useDiscreteGpu minMemory maxMemory;
      };
    };
  };

  # Prism instances map as XWayland class "Minecraft* <version>" (* = modded).
  gaming.windowClasses = ["^(Minecraft\\*? .*)$"];
}
