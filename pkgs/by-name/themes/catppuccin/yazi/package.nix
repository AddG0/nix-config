{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "catppuccin-yazi";
  version = "0-unstable-2026-08-20";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "yazi";
    rev = "d62802be39210ea10e54b3e3b09735c6cb9e57c1";
    hash = "sha256-bwzEO8exoBwa19q+jnYjHkaamGl2mhfukIEhDfUCRGI=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for Yazi";
    homepage = "https://github.com/catppuccin/yazi";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
