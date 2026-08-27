# Instantiate with `config.boot.kernelPackages.callPackage` so the module is
# built against the host's own kernel.
{
  lib,
  stdenv,
  kernel,
}:
stdenv.mkDerivation {
  pname = "razer-battery-care";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # Not kernel.makeFlags: that carries O= and --eval=undefine, for building the
  # kernel itself.
  makeFlags = [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  hardeningDisable = ["pic" "format"];

  installPhase = ''
    runHook preInstall
    install -Dm444 razer_battery_care.ko \
      -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hid"
    runHook postInstall
  '';

  meta = {
    description = "Razer Blade Battery Health Optimizer as a power_supply charge_types provider";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
