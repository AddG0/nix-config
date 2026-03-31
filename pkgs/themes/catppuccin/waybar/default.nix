{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "waybar-catppuccin";
  version = "1.1-unstable-2024-07-13";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "waybar";
    rev = "ee8ed32b4f63e9c417249c109818dcc05a2e25da";
    sha256 = "sha256-za0y6hcN2rvN6Xjf31xLRe4PP0YyHu2i454ZPjr+lWA=";
  };

  installPhase = ''
    mkdir -p $out/share/waybar-catppuccin
    cp -r themes/* $out/share/waybar-catppuccin/
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for Waybar";
    homepage = "https://github.com/catppuccin/waybar";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
