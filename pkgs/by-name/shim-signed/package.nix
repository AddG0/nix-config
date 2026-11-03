# Ubuntu's Microsoft-signed shim and MokManager, for firmware whose Secure Boot keys can't be replaced.
{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "shim-signed";
  version = "1.59+15.8-0ubuntu2";

  # Bump to the newest Launchpad build when Microsoft revokes older shims through an SBAT update.
  src = fetchurl {
    url = "https://launchpad.net/ubuntu/+archive/primary/+files/shim-signed_${finalAttrs.version}_amd64.deb";
    hash = "sha256-+O1xzi2RowS21euEmX+EbzMbVUV4vALb/njhOtisgak=";
  };

  nativeBuildInputs = [dpkg];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 usr/lib/shim/shimx64.efi.signed.latest $out/share/shim/shimx64.efi
    install -Dm444 usr/lib/shim/mmx64.efi $out/share/shim/mmx64.efi
    runHook postInstall
  '';

  meta = {
    description = "Microsoft-signed shim and MokManager from Ubuntu";
    homepage = "https://launchpad.net/ubuntu/+source/shim-signed";
    license = lib.licenses.bsd2;
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
