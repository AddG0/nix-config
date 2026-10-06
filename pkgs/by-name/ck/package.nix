# CK: Chidamber & Kemerer class metrics (CBO, WMC, RFC, LCOM, DIT) for Java source.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  jdk,
}:
stdenvNoCC.mkDerivation rec {
  pname = "ck";
  version = "0.7.0";

  src = fetchurl {
    url = "https://repo1.maven.org/maven2/com/github/mauricioaniche/ck/${version}/ck-${version}-jar-with-dependencies.jar";
    hash = "sha256-Ld/cJ1trWcIDPgMlPE/sURwzj+SUoQtw9lG8A5pyx00=";
  };

  dontUnpack = true;
  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/java $out/bin
    cp $src $out/share/java/ck.jar
    makeWrapper ${lib.getExe jdk} $out/bin/ck --add-flags "-jar $out/share/java/ck.jar"
    runHook postInstall
  '';

  meta = {
    description = "Code metrics for Java using static analysis (CK suite)";
    homepage = "https://github.com/mauricioaniche/ck";
    license = lib.licenses.asl20;
    mainProgram = "ck";
    platforms = lib.platforms.all;
  };
}
