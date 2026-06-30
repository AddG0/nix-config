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
  release = "20260602";
  pkgrel = "3";
in
  stdenv.mkDerivation {
    pname = "proton-cachyos";
    version = "${base}.${release}-${pkgrel}";

    # Upstream split into -native/-slr variants; -native is the build we use.
    src = fetchurl {
      url = "https://mirror.cachyos.org/repo/x86_64/cachyos/proton-cachyos-native-1:${base}.${release}-${pkgrel}-x86_64.pkg.tar.zst";
      name = "proton-cachyos-native-${base}.${release}-${pkgrel}.pkg.tar.zst";
      hash = "sha256-qUE+hoGiyhLLRuXUVPBClXWzgM2QHw/qlqbQa5Csl+8=";
    };

    nativeBuildInputs = [zstd];

    dontUnpack = true;

    # Upstream protonfixes ships some gamefixes as symlinks to others (games
    # that share a fix); a few targets aren't included in the archive, leaving
    # harmless dangling symlinks. protonfixes falls back to defaults when a fix
    # is absent, so opt out of nixpkgs' noBrokenSymlinks fixup check rather than
    # failing the build.
    dontCheckForBrokenSymlinks = true;

    passthru.updateScript = [./update.sh];

    installPhase = ''
      runHook preInstall

      tar -I zstd -xf $src
      mkdir -p $out/share/steam/compatibilitytools.d
      mv usr/share/steam/compatibilitytools.d/proton-cachyos-native $out/share/steam/compatibilitytools.d/

      substituteInPlace $out/share/steam/compatibilitytools.d/proton-cachyos-native/compatibilitytool.vdf \
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
