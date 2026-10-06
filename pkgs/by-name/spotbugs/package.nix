# SpotBugs bytecode bug-pattern detector; not packaged in nixpkgs.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  jdk,
}:
stdenvNoCC.mkDerivation rec {
  pname = "spotbugs";
  version = "4.10.4";

  src = fetchurl {
    url = "https://github.com/spotbugs/spotbugs/releases/download/${version}/spotbugs-${version}.tgz";
    hash = "sha256-crwNTt1obkYsD3H0KgSbJ79NpnCHl/97K1bdICcUtOU=";
  };

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/spotbugs $out/bin
    cp -r lib $out/libexec/spotbugs/
    makeWrapper ${lib.getExe jdk} $out/bin/spotbugs \
      --add-flags "-jar $out/libexec/spotbugs/lib/spotbugs.jar"
    runHook postInstall
  '';

  meta = {
    description = "Static analysis for bug patterns in JVM bytecode";
    homepage = "https://spotbugs.github.io";
    license = lib.licenses.lgpl21Plus;
    mainProgram = "spotbugs";
    platforms = lib.platforms.all;
  };
}
