{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "catppuccin-hyprland";
  version = "2.0.0-unstable-2026-05-25";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "hyprland";
    rev = "9f03f26fc10a00e00ec6b2ac2a41e44d16297548";
    hash = "sha256-jGqBpSQa793phan9PeU2yXMX1nxzYClthQSeTwdqgEQ=";
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
