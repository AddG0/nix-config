{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-hud";
  version = "0.0.12";

  src = fetchFromGitHub {
    owner = "jarrodwatts";
    repo = "claude-hud";
    rev = "30e1dfe46ad7b9a39ca2a4df7c735aaa33a90fd9";
    sha256 = "1apc6x1yfq9rvwx11ad02jsfxscb3cvvl2l6c4dymgqa9b2kx6gg";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude-code/plugins/claude-hud
    cp -r . $out/share/claude-code/plugins/claude-hud/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Real-time statusline HUD for Claude Code";
    homepage = "https://github.com/jarrodwatts/claude-hud";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
