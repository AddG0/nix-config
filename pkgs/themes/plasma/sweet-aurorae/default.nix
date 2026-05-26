{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "sweet-aurorae";
  version = "2.0-unstable-2026-05-06";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet";
    rev = "5ce81a45f0f0b63cf732317e7f91f3467ccce084"; # nova branch
    sha256 = "sha256-IQjp6g+0ADwivZji3LmOs5GRJys+aLbEMrGSEW3devc=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/aurorae/themes

    # Copy KDE Aurorae themes from the nova branch
    # The nova branch contains proper Aurorae SVG themes
    cp -r $src/kde/aurorae/* $out/share/aurorae/themes/

    runHook postInstall
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Sweet window decoration theme for KDE/Aurorae";
    homepage = "https://github.com/EliverLara/Sweet";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
