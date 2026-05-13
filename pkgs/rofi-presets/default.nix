{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "rofi-presets";
  version = "0-unstable-2026-04-30";

  src = fetchFromGitHub {
    owner = "adi1090x";
    repo = "rofi";
    rev = "b0bfe927531e365f009d01810c26878c003f7cb8";
    sha256 = "sha256-pM183MHOMuKJyLgthozM1MRsmhBM25VQgWc7CmLL2HI=";
  };

  installPhase = ''
    mkdir -p $out/share/rofi-presets
    cp -r files/* $out/share/rofi-presets/
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "A huge collection of Rofi based custom Applets, Launchers & Powermenus";
    homepage = "https://github.com/adi1090x/rofi";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
