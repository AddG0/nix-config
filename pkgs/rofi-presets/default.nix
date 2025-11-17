{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "rofi-presets";
  version = "unstable-2024-01-14";

  src = fetchFromGitHub {
    owner = "adi1090x";
    repo = "rofi";
    rev = "2e0efe5054ac7eb502a585dd6b3575a65b80ce72";
    sha256 = "sha256-TVZ7oTdgZ6d9JaGGa6kVkK7FMjNeuhVTPNj2d7zRWzM=";
  };

  installPhase = ''
    mkdir -p $out/share/rofi-presets
    cp -r files/* $out/share/rofi-presets/
  '';

  meta = with lib; {
    description = "A huge collection of Rofi based custom Applets, Launchers & Powermenus";
    homepage = "https://github.com/adi1090x/rofi";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
