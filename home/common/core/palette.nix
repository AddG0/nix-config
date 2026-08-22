{
  config,
  lib,
  ...
}: {
  # Shared rather than living in the one program that first needed it, so every
  # target resolves the same tone.
  lib.palette.muted = lib.custom.colors.muted config.lib.stylix.colors.withHashtag;
}
