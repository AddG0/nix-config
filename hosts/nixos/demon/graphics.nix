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
    # New Feature Branch: 610 is the first to expose nvenc API 13.1, which
    # gpu-screen-recorder demands when built against ffmpeg 9 (avcodec 63).
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
