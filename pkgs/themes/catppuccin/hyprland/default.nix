{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "catppuccin-hyprland";
  version = "1.3-unstable-2024-06-19";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "hyprland";
    rev = "c388ac55563ddeea0afe9df79d4bfff0096b146b";
    hash = "sha256-xSa/z0Pu+ioZ0gFH9qSo9P94NPkEMovstm1avJ7rvzM=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for Hyprland";
    homepage = "https://github.com/catppuccin/hyprland";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
