{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "squash2";
  version = "0-unstable-2026-01-23";

  src = fetchFromGitHub {
    owner = "Shaurya-Kalia";
    repo = "squash2";
    rev = "2aedc7c5ea9f988631cf8fb79903d2ec7d8dce8b";
    hash = "sha256-lNHWgjDxX2BjB4S9z37JUsR/aUwxS/KhsgJJCsaxa0Y=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/kwin/effects/kwin4_effect_squash2
    cp -r * $out/share/kwin/effects/kwin4_effect_squash2/

    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "An effect to minimise and unminimise windows, modified from the default effect to be more in line with gnome animation schemes";
    homepage = "https://github.com/Shaurya-Kalia/squash2";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
