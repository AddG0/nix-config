{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "vimix-cursors";
  version = "2020-02-24-unstable-2021-09-18";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Vimix-cursors";
    rev = "9bc292f40904e0a33780eda5c5d92eb9a1154e9c";
    sha256 = "sha256-zW7nJjmB3e+tjEwgiCrdEe5yzJuGBNdefDdyWvgYIUU=";
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

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Vimix cursor theme inspired by Materia design";
    homepage = "https://github.com/vinceliuice/Vimix-cursors";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
