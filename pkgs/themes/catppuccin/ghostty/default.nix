{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "catppuccin-ghostty";
  version = "0-unstable-2026-01-07";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "ghostty";
    rev = "5a58926563ddacbde4a12b4a347464c2c6945393";
    sha256 = "sha256-Y6RFften1/6+1xdhIzEh/E7FBJTwY5a8NH4301HbgOM=";
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
    platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  };
}
