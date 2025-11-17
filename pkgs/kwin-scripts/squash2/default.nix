{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "squash2";
  version = "unstable-2024-12-19";

  src = fetchFromGitHub {
    owner = "Shaurya-Kalia";
    repo = "squash2";
    rev = "main";
    sha256 = "095xvhw9cj3z67vlf9xzw09hy5jfp9jk672wh5zmlkk31gv4w6fz";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/kwin/effects/kwin4_effect_squash2
    cp -r * $out/share/kwin/effects/kwin4_effect_squash2/

    runHook postInstall
  '';

  meta = with lib; {
    description = "An effect to minimise and unminimise windows, modified from the default effect to be more in line with gnome animation schemes";
    homepage = "https://github.com/Shaurya-Kalia/squash2";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
