{
  lib,
  python3,
  makeWrapper,
  stdenv,
}: let
  pythonEnv = python3.withPackages (ps:
    with ps; [
      bleak
      pydantic
      pydantic-settings
    ]);
in
  stdenv.mkDerivation {
    pname = "bt-proximity-monitor";
    version = "1.0.0";

    src = ./.;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      mkdir -p $out/bin
      cp monitor.py $out/bin/bt-proximity-monitor
      chmod +x $out/bin/bt-proximity-monitor

      wrapProgram $out/bin/bt-proximity-monitor \
        --prefix PATH : ${lib.makeBinPath [pythonEnv]} \
        --set PYTHONPATH ${pythonEnv}/${python3.sitePackages}
    '';

    meta = with lib; {
      description = "Bluetooth proximity-based screen locking monitor using bleak (no pairing required)";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  }
