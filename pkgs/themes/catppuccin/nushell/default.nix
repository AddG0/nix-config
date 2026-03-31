{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "catppuccin-nushell";
  version = "0-unstable-2025-12-24";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "nushell";
    rev = "815dfc6ea61f2746ff27b54ef425cfeb7b51dda8";
    sha256 = "sha256-124T2pCmwirl8eLAy3h1fDOQZJf//3KJ7GwIP+u6YQ4=";
  };

  installPhase = ''
    mkdir -p $out/share/nu-themes
    cp themes/*.nu $out/share/nu-themes/
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for Nushell";
    homepage = "https://github.com/catppuccin/nushell";
    license = licenses.mit;
    platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    maintainers = [];
  };
}
