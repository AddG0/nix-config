{
  lib,
  stdenvNoCC,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "xcursor-to-cape";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (f: f.hasExt "py") ./.;
  };

  nativeCheckInputs = [python3];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -m unittest -v test_xcursor_to_cape
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 xcursor_to_cape.py $out/libexec/xcursor_to_cape.py
    mkdir -p $out/bin
    printf '#!/bin/sh\nexec %s %s "$@"\n' ${python3.interpreter} $out/libexec/xcursor_to_cape.py > $out/bin/xcursor-to-cape
    chmod +x $out/bin/xcursor-to-cape
    runHook postInstall
  '';

  meta = {
    description = "Convert an XCursor theme into a Mousecape .cape file";
    license = lib.licenses.mit;
    mainProgram = "xcursor-to-cape";
    platforms = lib.platforms.all;
  };
}
