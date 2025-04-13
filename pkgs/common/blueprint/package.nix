{
  lib,
  stdenv,
  fetchFromGitHub,
  unzip,
  nodejs,
  yarn,
}:
stdenv.mkDerivation rec {
  pname = "blueprint";
  version = "unstable-2024-04-13";

  src = fetchFromGitHub {
    owner = "BlueprintFramework";
    repo = "framework";
    rev = "latest";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # This will be updated by nix-prefetch-url
  };

  nativeBuildInputs = [unzip nodejs yarn];

  buildPhase = ''
    unzip $src
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
    chmod +x $out/blueprint.sh
  '';

  meta = with lib; {
    description = "A framework for Pterodactyl panel extensions";
    homepage = "https://github.com/BlueprintFramework/framework";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
