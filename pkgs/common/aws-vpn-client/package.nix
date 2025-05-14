{
  stdenv,
  lib,
  xar,
  cpio,
  fetchurl,
  pname ? "aws-vpn-client",
  version ? "3.9.0",
  meta ? {},
}:
# https://d20adtppz83p9s.cloudfront.net/OSX/latest/AWS_VPN_Client.pkg
stdenv.mkDerivation {
  pname = pname;
  version = version;
  src = fetchurl {
    url = "https://d20adtppz83p9s.cloudfront.net/OSX/latest/AWS_VPN_Client.pkg";
    # url = "https://d20adtppz83p9s.cloudfront.net/OSX/${version}/AWS_VPN_Client.pkg";
    # Replace the hash below with the actual hash of the package.
    hash = "sha256-8PalV5/pQxV3RS6KrAckHDbLNMKz8Cjf3Qf0HQD/gNg=";
  };

  passthru.updateScript = null;

  meta =
    meta
    // {
      description = "AWS VPN Client";
      homepage = "https://aws.amazon.com/vpn/";
      license = lib.licenses.unfree;
      platforms = ["x86_64-darwin" "aarch64-darwin"];
      maintainers = ["addg0"];
    };

  buildInputs = [xar cpio];

  # Unpack the .pkg file using xar.
  unpackPhase = ''
    runHook preUnpack
    # This extracts the contents of the pkg into a directory.
    xar -xf "$src"
    runHook postUnpack
  '';

  # Build phase: extract the Payload (a gzipped cpio archive)
  buildPhase = ''
    runHook preBuild
    # Change into the directory created by xar extraction.
    if [ -d "AWS_VPN_Client.pkg" ]; then
      cd AWS_VPN_Client.pkg
    else
      echo "Error: Expected directory 'AWS_VPN_Client.pkg' not found"
      exit 1
    fi
    mkdir -p ../payload
    # Extract the gzipped Payload into the ../payload directory.
    cat Payload | gunzip -dc | (cd ../payload && cpio -id)
    runHook postBuild
  '';

  # Install phase: copy the resulting app bundle.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    ls ../payload
    cp -R ../payload/AWS\ VPN\ Client/AWS\ VPN\ Client.app "$out/Applications/AWS VPN Client.app"
    runHook postInstall
  '';

  dontFixup = true;
}
