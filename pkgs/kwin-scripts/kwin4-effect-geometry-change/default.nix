{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "kwin4-effect-geometry-change";
  version = "1.5";

  src = fetchFromGitHub {
    owner = "peterfajdiga";
    repo = "kwin4_effect_geometry_change";
    rev = "v${version}";
    sha256 = "084pfl38mcqb508lhgspl1np5khqddpg2h5zz9i3rw0im2lnk0d7";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/kwin/effects
    cp -r package/* $out/share/kwin/effects/

    runHook postInstall
  '';

  meta = with lib; {
    description = "A KWin animation for windows moved or resized by programs or scripts";
    homepage = "https://github.com/peterfajdiga/kwin4_effect_geometry_change";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
