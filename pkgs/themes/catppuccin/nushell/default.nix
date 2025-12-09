{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "catppuccin-nushell";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "nushell";
    rev = "c0568b4a78f04be24f68c80284755d4635647aa1";
    sha256 = "sha256-vaGiZHoGkHr1QcshO8abIQL/zIuw3hFcBhDYcKhOpNw=";
  };

  installPhase = ''
    mkdir -p $out/share/nu-themes
    cp themes/*.nu $out/share/nu-themes/
  '';

  meta = with lib; {
    description = "Soothing pastel theme for Nushell";
    homepage = "https://github.com/catppuccin/nushell";
    license = licenses.mit;
    platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    maintainers = [];
  };
}
