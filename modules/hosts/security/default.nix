{lib, ...}: {
  imports = [
    ./firewall.nix
    ./allow-poweroff.nix
  ];
}
