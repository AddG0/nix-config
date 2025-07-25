{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-ghostty";
  version = "main";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "ghostty";
    rev = "main";
    sha256 = "sha256-zJrL3ndgUJ8E8O5RpJf5VAmnDMcOrMdnHDQE5DQyIO4=";
  };

  installPhase = ''
    mkdir -p $out/share/ghostty-catppuccin
    cp -r themes/* $out/share/ghostty-catppuccin/
  '';

  meta = with lib; {
    description = "Soothing pastel theme for Ghostty";
    homepage = "https://github.com/catppuccin/ghostty";
    license = licenses.mit;
    platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  };
}
