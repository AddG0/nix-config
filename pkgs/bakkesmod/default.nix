{
  lib,
  stdenv,
  fetchzip,
  innoextract,
}:
stdenv.mkDerivation {
  pname = "bakkesmod";
  version = "2.0.60";

  src = fetchzip {
    url = "https://github.com/bakkesmodorg/BakkesModInjectorCpp/releases/download/2.0.60/BakkesModSetup.zip";
    sha256 = "sha256-Kx9Phyq45T1shuRebthIJdaAPGmkzZ2Huvhgg4xNnKU=";
    stripRoot = false;
  };

  nativeBuildInputs = [innoextract];

  unpackPhase = ''
    cp $src/BakkesModSetup.exe .
  '';

  buildPhase = ''
    innoextract BakkesModSetup.exe
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp app/BakkesMod.exe $out/bin/
  '';

  meta = with lib; {
    description = "BakkesMod - Rocket League mod framework";
    homepage = "https://bakkesmod.com/";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
