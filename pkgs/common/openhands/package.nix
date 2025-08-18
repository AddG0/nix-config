{
  lib,
  stdenv,
  uv,
  python312,
  makeWrapper,
  gcc-unwrapped,
  autoPatchelfHook,
  ...
}:
stdenv.mkDerivation rec {
  pname = "openhands";
  version = "0.53.0";

  # No source needed, we're just creating a wrapper
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Create a wrapper script that launches OpenHands with uv
    # Include LD_LIBRARY_PATH for native dependencies
    makeWrapper ${uv}/bin/uvx $out/bin/openhands \
      --add-flags "--python ${python312}/bin/python3.12" \
      --add-flags "--from openhands-ai" \
      --add-flags "openhands" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenHands: Code Less, Make More - A platform for software development agents powered by AI";
    homepage = "https://github.com/All-Hands-AI/OpenHands";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.all;
    mainProgram = "openhands";
  };
}