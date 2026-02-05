# gRPC Kotlin protoc plugin - generates Kotlin gRPC service stubs
# Usage: protoc --plugin=protoc-gen-grpc-kotlin --grpc-kotlin_out=...
{
  lib,
  stdenvNoCC,
  fetchurl,
  jdk21_headless,
  makeWrapper,
}:
stdenvNoCC.mkDerivation rec {
  pname = "protoc-gen-grpc-kotlin";
  version = "1.5.0";

  src = fetchurl {
    url = "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/${version}/protoc-gen-grpc-kotlin-${version}-jdk8.jar";
    hash = "sha256-2pOOkEenlz1TkW7uM6FGWtzh5y3OdRJ0dLiAg4gCMCY=";
  };

  dontUnpack = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/java $out/bin
    cp $src $out/share/java/protoc-gen-grpc-kotlin.jar

    makeWrapper ${jdk21_headless}/bin/java $out/bin/protoc-gen-grpc-kotlin \
      --add-flags "-jar $out/share/java/protoc-gen-grpc-kotlin.jar"

    runHook postInstall
  '';

  meta = with lib; {
    description = "gRPC Kotlin protoc plugin for generating Kotlin gRPC service stubs";
    homepage = "https://github.com/grpc/grpc-kotlin";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "protoc-gen-grpc-kotlin";
  };
}
