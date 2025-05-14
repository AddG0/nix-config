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
      automatic = true;
      options = "--delete-older-than 10d";
    };
  };
}
