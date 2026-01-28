{nix-secrets, ...}: {
  imports = [
    "${nix-secrets}/modules/shipperhq"
  ];
}
