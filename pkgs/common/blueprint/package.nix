{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  yarn,
  ncurses,
}:
stdenv.mkDerivation rec {
  pname = "blueprint";
  version = "unstable-2024-04-13";

  src = fetchFromGitHub {
    owner = "BlueprintFramework";
    repo = "framework";
    rev = "main";
    sha256 = "sha256-9gTKMhgcH55/PxfmLF0sPifDool16pj20AfjBas5Ses="; # This will be updated by nix-prefetch-url
  };

  nativeBuildInputs = [nodejs yarn ncurses];

  installPhase = ''
    mkdir -p $out
    cp -r $src/* $out/
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
