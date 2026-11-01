# Noctalia plugins: each is a self-contained module (files, enable, bar slot, services).
{
  lib,
  hostSpec,
  ...
}: {
  imports =
    [./next-event]
    # The hostSpec specialArg, since imports resolve before config; hosts without sops can't decrypt ai-usage's token.
    ++ lib.optionals (!hostSpec.disableSops) [./ai-usage];
}
