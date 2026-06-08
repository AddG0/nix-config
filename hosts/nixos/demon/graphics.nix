{
  inputs,
  config,
  ...
}: {
  imports = [
    "${inputs.hardware}/common/gpu/nvidia/blackwell"
  ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # TODO: Disable in BIOS`
  boot.kernelParams = ["module_blacklist=amdgpu,amdxcp,snd_hda_codec_atihdmi"];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
