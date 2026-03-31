{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "catppuccin-process-compose";
  version = "0-unstable-2024-07-20";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "process-compose";
    rev = "b0c48aa07244a8ed6a7d339a9b9265a3b561464d";
    sha256 = "sha256-uqJR9OPrlbFVnWvI3vR8iZZyPSD3heI3Eky4aFdT0Qo=";
  };

  installPhase = ''
    mkdir -p $out/share/process-compose-catppuccin
    cp -r themes/* $out/share/process-compose-catppuccin/
  '';

  passthru.nixUpdate.version = "branch";

  meta = with lib; {
    description = "Soothing pastel theme for process-compose";
    homepage = "https://github.com/catppuccin/process-compose";
    license = licenses.mit;
    platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  };
}
