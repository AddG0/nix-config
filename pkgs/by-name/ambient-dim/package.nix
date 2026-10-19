# Tune live: AMBIENT_DIM_VERBOSE=1 nix run .#ambient-dim -- --floor 0.3
{
  lib,
  stdenv,
  swift,
}:
stdenv.mkDerivation {
  pname = "ambient-dim";
  version = "0.1.0";

  src = ./.;

  # Local package: src = ./. has no upstream URL for nix-update to bump.
  passthru.nixUpdate.version = "skip";

  nativeBuildInputs = [swift];

  buildPhase = ''
    runHook preBuild
    swiftc -O -o ambient-dim Logic.swift main.swift
    runHook postBuild
  '';

  # Mapping and smoothing only; the sensor and gamma calls need real hardware.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    swiftc -o logic-tests Logic.swift tests/main.swift
    ./logic-tests
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ambient-dim $out/bin/ambient-dim
    runHook postInstall
  '';

  meta = {
    description = "Dims the MacBook display below its backlight floor to match a dark room";
    mainProgram = "ambient-dim";
    platforms = lib.platforms.darwin;
  };
}
