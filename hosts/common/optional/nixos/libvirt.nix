{
  pkgs,
  config,
  ...
}: {
  virtualisation = {
    spiceUSBRedirection.enable = true;

    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true; # TPM emulation for Windows 11 / macOS
    };
  };

  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    qemu
    virt-viewer
  ];

  users.users.${config.hostSpec.username}.extraGroups = ["libvirtd" "kvm"];
}
