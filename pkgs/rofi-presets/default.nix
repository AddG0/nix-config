{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "rofi-presets";
  version = "0-unstable-2025-07-26";

  src = fetchFromGitHub {
    owner = "adi1090x";
    repo = "rofi";
    rev = "093c1a79f58daab358199c4246de50357e5bf462";
    sha256 = "sha256-iUX0Quae06tGd7gDgXZo1B3KYgPHU+ADPBrowHlv02A=";
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
