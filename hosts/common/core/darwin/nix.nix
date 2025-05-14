{
  inputs,
  config,
  outputs,
  lib,
  ...
}: {
  nix = {
    gc.automatic = true;

    # Garbage Collection
    gc = {
      options = "--delete-older-than 10d";
    };
  };
}
