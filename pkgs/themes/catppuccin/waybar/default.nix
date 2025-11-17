{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "waybar-catppuccin";
  version = "unstable-2024-01-14";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "waybar";
    rev = "f74ab1eecf2dcaf22569b396eed53b2b2fbe8aff";
    sha256 = "sha256-WLJMA2X20E5PCPg0ZPtSop0bfmu+pLImP9t8A8V4QK8=";
  };

  installPhase = ''
    mkdir -p $out/share/waybar-catppuccin
    cp -r themes/* $out/share/waybar-catppuccin/
  '';

  meta = with lib; {
    description = "Soothing pastel theme for Waybar";
    homepage = "https://github.com/catppuccin/waybar";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
