{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-ghostty";
  version = "0-unstable-2026-11-14";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "ghostty";
    rev = "92b40c1137b647bdc21f999c098d19d3f59a0227";
    sha256 = "sha256-Heq2TMby/wFGt3pany9cQlnbvQD2+5qtnFxbZKpwkcI=";
  };

  installPhase = ''
    mkdir -p $out/share/ghostty-catppuccin
    cp -r themes/* $out/share/ghostty-catppuccin/
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for Ghostty";
    homepage = "https://github.com/catppuccin/ghostty";
    license = licenses.mit;
    platforms = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
  };
}
