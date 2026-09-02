{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-ghostty";
  version = "0-unstable-2026-08-28";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "ghostty";
    rev = "b0b03ccee7ae8f16b13bd4fdfe267616defdb2b7";
    sha256 = "sha256-XwUwWdBLyFwfyL9/kUhJaztTj+s3JShyc15YAA2HPaY=";
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
