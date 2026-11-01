#############################################################
#
#  installer - USB stick `just bootstrap` installs hosts from; see docs/automation/justfile.md.
#
###############################################################
{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"

    (with lib.custom.optional.hosts.nixos.desktops; [common plasma6])
    (with lib.custom.optional.hosts.nixos.services; [openssh])
  ];

  hostSpec = {
    hostName = "installer";
    hostPlatform = "x86_64-linux";
    # A live USB has no host key to decrypt sops with.
    disableSops = true;
  };

  # The installer profile adds ZFS support; nothing here boots a ZFS root.
  boot.zfs.forceImportRoot = false;

  networking.networkmanager.enable = true;

  services = {
    # nixos-anywhere installs as root, run from demon by `just bootstrap`.
    openssh.settings.PermitRootLogin = "prohibit-password";

    displayManager.autoLogin.enable = true;
  };

  # root has no home-manager zshrc, so zsh would greet every ssh login with its new-user wizard.
  users.users.root.shell = lib.mkForce pkgs.bashInteractive;

  # Calamares, for a plain NixOS install without `just bootstrap`: the calamares profile minus its autostart.
  programs.partition-manager.enable = true;
  security.polkit = {
    enablePkexecWrapper = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  environment.systemPackages = with pkgs; [
    calamares-nixos
    calamares-nixos-extensions
    glibcLocales
    gparted
    nixos-facter
  ];

  time.timeZone = "America/Chicago";
}
