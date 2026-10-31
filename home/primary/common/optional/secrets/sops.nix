{
  config,
  inputs,
  ...
}: {
  sops.defaultSopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.primaryUsername}/personal.yaml";
}
