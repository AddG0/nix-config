# PMD 7 static analysis and CPD copy-paste detection; nixpkgs is stuck on 6.55.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  jdk,
}:
stdenvNoCC.mkDerivation rec {
  pname = "pmd";
  version = "7.28.0";

  src = fetchurl {
    url = "https://github.com/pmd/pmd/releases/download/pmd_releases%2F${version}/pmd-dist-${version}-bin.zip";
    hash = "sha256-+XS6Vx97wBxz//4Rut4l+8H0OGmPnpwA5Bbo1l6fusI=";
  };

  nativeBuildInputs = [unzip makeWrapper];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/pmd $out/bin
    cp -r . $out/libexec/pmd
    makeWrapper $out/libexec/pmd/bin/pmd $out/bin/pmd \
      --set JAVA_HOME ${jdk} --prefix PATH : ${lib.makeBinPath [jdk]}
    runHook postInstall
  '';

  meta = {
    description = "Extensible multilanguage static code analyzer, with CPD duplicate detection";
    homepage = "https://pmd.github.io";
    license = with lib.licenses; [bsdOriginal asl20];
    mainProgram = "pmd";
    platforms = lib.platforms.all;
  };
}
