{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-kde";
  version = "0-unstable-2025-04-25";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet-kde";
    rev = "9f311e1497c749c5463007dcaf15c06376b4db5f";
    sha256 = "sha256-rGDXRZiIddn2t8mVQNdwpe/loe+9IIe++E7BGu42AKA=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/plasma/desktoptheme
    mkdir -p $out/share/color-schemes

    # Install plasma theme
    cp -r $src $out/share/plasma/desktoptheme/Sweet

    # Install color scheme
    cp $src/colors $out/share/color-schemes/Sweet.colors

    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "A dark and modern theme for KDE Plasma";
    homepage = "https://github.com/EliverLara/Sweet-kde";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
