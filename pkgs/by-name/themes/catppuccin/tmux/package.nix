{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-tmux";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "tmux";
    rev = "v${version}";
    sha256 = "sha256-3CJRQCgS8NAN7vOLBjNGiHbGXTIrIyY/FLmfZrXcEYc=";
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
