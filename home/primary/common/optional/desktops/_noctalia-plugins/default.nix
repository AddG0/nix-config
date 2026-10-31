# Noctalia plugins: each is a self-contained module (files, enable, bar slot, services).
{
  inputs,
  lib,
  hostSpec,
  ...
}: {
  imports =
    [
      ./ai-usage
      ./next-event
    ]
    # The hostSpec specialArg, since imports resolve before config; hosts without sops can't fetch nix-secrets.
    ++ lib.optional (!hostSpec.disableSops) inputs.nix-secrets.homeModules.dd;
}
