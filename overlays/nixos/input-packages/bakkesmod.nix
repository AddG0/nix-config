# Under overlays/nixos because BakkesMod is a Windows injector run through
# Proton, so it has nothing to offer darwin.
{inputs, ...}: inputs.bakkesmod-nix.overlays.default
