{
  lib,
  python3,
  makeWrapper,
  stdenv,
}: let
  pythonEnv = python3.withPackages (ps:
    with ps; [
      bleak
      rich
    ]);
in
  stdenv.mkDerivation {
    pname = "bt-scan";
    version = "1.0.0";

    src = ./.;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      mkdir -p $out/bin
      cp scan.py $out/bin/bt-scan
      chmod +x $out/bin/bt-scan

      wrapProgram $out/bin/bt-scan \
        --prefix PATH : ${lib.makeBinPath [pythonEnv]} \
        --set PYTHONPATH ${pythonEnv}/${python3.sitePackages}
    '';

    meta = with lib; {
      description = "Continuous BLE device scanner with live table display";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  }
