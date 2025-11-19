{
  lib,
  stdenv,
  unzip,
  curl,
  jq,
  cacert,
}:
# Builder function for BakkesMod plugins
{
  pname,
  version ? "latest",
  pluginId, # ID on bakkesplugins.com
  sha256,
  description ? "",
  meta ? {},
}:
stdenv.mkDerivation {
  inherit pname version;

  # Build phase that fetches the CDN URL and downloads the plugin
  nativeBuildInputs = [curl jq unzip cacert];

  dontUnpack = true;

  buildPhase = ''
    # Fetch the CDN URL from the API
    echo "Fetching CDN URL for plugin ${pluginId}..."
    CDN_URL=$(curl -s "https://bakkesplugins.com/api/plugins/${pluginId}/versions" | \
      jq -r '.[0].binaryDownloadUrl')

    if [ -z "$CDN_URL" ] || [ "$CDN_URL" = "null" ]; then
      echo "Failed to fetch CDN URL for plugin ${pluginId}"
      exit 1
    fi

    echo "Downloading from: $CDN_URL"
    curl -L -o plugin.zip "$CDN_URL"
  '';

  installPhase = ''
    mkdir -p $out/share/bakkesmod

    # Extract everything from the zip to the bakkesmod root
    # This preserves the structure: data/, plugins/, etc.
    unzip -q plugin.zip -d $out/share/bakkesmod/ || true
  '';

  # We need to make this a fixed-output derivation for the download
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = sha256;

  meta = with lib;
    {
      inherit description;
      license = licenses.unfree;
      platforms = platforms.linux;
    }
    // meta;
}
