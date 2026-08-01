{
  inputs,
  config,
  ...
}: {
  imports = [
    "${inputs.hardware}/common/gpu/nvidia/turing"
  ];

  hardware.graphics.enable = true;

  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;

  # Overrides nixos-hardware's turing module, which turns the open ones on: they
  # log a burst of NVRM bad-register reads on this card every boot.
  hardware.nvidia.open = false;
}
