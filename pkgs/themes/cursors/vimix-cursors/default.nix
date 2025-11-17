{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "vimix-cursors";
  version = "2020-02-24";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Vimix-cursors";
    rev = "2020-02-24";
    sha256 = "sha256-TfcDer85+UOtDMJVZJQr81dDy4ekjYgEvH1RE1IHMi4=";
  };

  # No build dependencies needed since we're using pre-built cursors
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons

    # Copy the cursor themes with proper names
    cp -r dist $out/share/icons/Vimix-cursors
    cp -r dist-white $out/share/icons/Vimix-white-cursors

    runHook postInstall
  '';

  meta = with lib; {
    description = "Vimix cursor theme inspired by Materia design";
    homepage = "https://github.com/vinceliuice/Vimix-cursors";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
