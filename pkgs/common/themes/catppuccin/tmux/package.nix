{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-tmux";
  version = "v2.1.3";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "tmux";
    rev = version;
    sha256 = "sha256-RlgTeBkjEvZpkZbhIss3KxQcvt0goy4WU+w9d2XCOnw=";
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
    maintainers = [maintainers.addg0];
  };
}
