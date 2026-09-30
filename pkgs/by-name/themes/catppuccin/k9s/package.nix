{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "catppuccin-k9s";
  version = "0-unstable-2024-07-20";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "k9s";
    rev = "fdbec82284744a1fc2eb3e2d24cb92ef87ffb8b4";
    hash = "sha256-9h+jyEO4w0OnzeEKQXJbg9dvvWGZYQAO4MbgDn6QRzM=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for k9s";
    homepage = "https://github.com/catppuccin/k9s";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
