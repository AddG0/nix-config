{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-tmux";
  version = "2.1.3";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "tmux";
    rev = "v${version}";
    sha256 = "sha256-Is0CQ1ZJMXIwpDjrI5MDNHJtq+R3jlNcd9NXQESUe2w=";
  };

  installPhase = ''
    mkdir -p $out/share/tmux-plugins/catppuccin
    cp -r * $out/share/tmux-plugins/catppuccin/
  '';

  meta = with lib; {
    description = "Soothing pastel theme for tmux";
    homepage = "https://github.com/catppuccin/tmux";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
