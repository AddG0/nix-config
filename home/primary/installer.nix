{
  config,
  lib,
  pkgs,
  ...
}: let
  # [package desktop-file]
  apps = with pkgs; [
    [gnome-disk-utility "org.gnome.DiskUtility.desktop"]
    [kdePackages.filelight "org.kde.filelight.desktop"]
    [kdePackages.dolphin "org.kde.dolphin.desktop"]
    [kdePackages.kate "org.kde.kate.desktop"]
    [mission-center "io.missioncenter.MissionCenter.desktop"]
  ];
  # Installed elsewhere: the system has the polkit apps, whose actions polkit reads only from there.
  iconsOnly = with pkgs; [
    [calamares-nixos "calamares.desktop"]
    [gparted "gparted.desktop"]
    [kdePackages.partitionmanager "org.kde.partitionmanager.desktop"]
    [gsmartcontrol "gsmartcontrol.desktop"]
    [config.programs.btop.package "btop.desktop"]
    [config.programs.ghostty.package "com.mitchellh.ghostty.desktop"]
    [config.programs.zen-browser.package "zen-beta.desktop"]
  ];
in {
  imports = lib.flatten [
    (with lib.custom.optional.home; [ghostty])
  ];

  home = {
    packages = map lib.head apps;
    file = lib.listToAttrs (map (icon: {
        name = "Desktop/${lib.last icon}";
        value.source = "${lib.head icon}/share/applications/${lib.last icon}";
      })
      (apps ++ iconsOnly));
  };

  programs = {
    # Their toolchains and servers are most of the closure, and nobody codes on the stick.
    nixvim = {options, ...}: {
      languages = lib.mapAttrs (name: _: {enable = lib.elem name ["json" "lua" "nix" "shell" "yaml"];}) options.languages;
    };

    # Plain Zen; the browsers module is the configured one.
    zen-browser = {
      enable = true;
      profiles.default.settings."zen.welcome-screen.seen" = true;
    };

    plasma = {
      enable = true;
      workspace.lookAndFeel = "org.kde.breezedark.desktop";
      # Terminal apps on the desktop, like btop, open in this.
      configFile.kdeglobals.General = {
        TerminalApplication = "ghostty";
        TerminalService = "com.mitchellh.ghostty.desktop";
      };
    };
  };
}
