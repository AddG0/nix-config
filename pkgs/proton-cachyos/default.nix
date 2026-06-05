{
  lib,
  stdenv,
  fetchurl,
  zstd,
  # Can be overridden to alter the display name in steam.
  # Useful if multiple versions should be installed together.
  steamDisplayName ? "Proton CachyOS",
}: let
  base = "11.0";
  release = "20260521";
  pkgrel = "3";
in
  stdenv.mkDerivation {
    pname = "proton-cachyos";
    version = "${base}.${release}-${pkgrel}";

    src = fetchurl {
      url = "https://mirror.cachyos.org/repo/x86_64/cachyos/proton-cachyos-1:${base}.${release}-${pkgrel}-x86_64.pkg.tar.zst";
      name = "proton-cachyos-${base}.${release}-${pkgrel}.pkg.tar.zst";
      hash = "sha256-CIpWz6br+LMF/vPnslwmfVoX4c3GQpMAGXNYwrZD3Og=";
    };

    nativeBuildInputs = [zstd];

    dontUnpack = true;

    passthru.updateScript = [./update.sh];

    installPhase = ''
      runHook preInstall

      tar -I zstd -xf $src
      mkdir -p $out/share/steam/compatibilitytools.d
      mv usr/share/steam/compatibilitytools.d/proton-cachyos $out/share/steam/compatibilitytools.d/

      substituteInPlace $out/share/steam/compatibilitytools.d/proton-cachyos/compatibilitytool.vdf \
        --replace-fail '"display_name" "proton-cachyos-${base}-${release} (native)"' '"display_name" "${steamDisplayName}"'

      runHook postInstall
    '';

    meta = with lib; {
      description = "CachyOS Proton build with additional patches and optimizations";
      homepage = "https://github.com/CachyOS/proton-cachyos";
      license = licenses.bsd3;
      platforms = ["x86_64-linux"];
      maintainers = [];
      sourceProvenance = with sourceTypes; [binaryNativeCode];
    };
  }
