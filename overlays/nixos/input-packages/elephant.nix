# Pin elephant to walker's own elephant input, patched so the
# desktopapplications provider never shows a matched Exec verbatim — on Nix
# that's a /nix/store/<hash>-... path long enough to win the fuzzy match and
# leak into the launcher's subtitle. Search still covers Exec; only the
# display fallback changes (falls back to GenericName instead).
#
# FLAKE-UPDATE: drop `elephant-bin`/`providers` below and go back to
# `inputs.walker.inputs.elephant.packages.${system}.elephant`/
# `.elephant-providers` once abenz1267/elephant's flake.nix stops hardcoding
# `pkgs.buildGo125Module` (nixpkgs removed that builder once Go 1.25 went EOL,
# so referencing it now throws at eval time).
{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (let
  system = prev.stdenv.hostPlatform.system;
  src = inputs.walker.inputs.elephant;
  version = prev.lib.trim (builtins.readFile "${src}/cmd/elephant/version.txt");
  vendorHash = "sha256-EWXZ+9/QDRpidpVHBcfJgp0xoc3YtRsiC/UTk1R+FSY=";

  elephant-bin = prev.buildGoModule {
    pname = "elephant";
    inherit version src vendorHash;
    buildInputs = [prev.protobuf];
    nativeBuildInputs = [prev.protoc-gen-go prev.makeWrapper];
    subPackages = ["cmd/elephant"];
    postFixup = ''
      wrapProgram $out/bin/elephant \
        --prefix PATH : ${prev.lib.makeBinPath [prev.fd]}
    '';
  };

  providers = prev.buildGoModule rec {
    pname = "elephant-providers";
    inherit version src vendorHash;
    buildInputs = [prev.wayland];
    nativeBuildInputs = [prev.protobuf prev.protoc-gen-go];

    postPatch = ''
      substituteInPlace internal/providers/desktopapplications/query.go \
        --replace-fail 'if ok && match != v.Name {' 'if ok && match != v.Name && match != v.Exec {' \
        --replace-fail 'if ok && match != a.Name {' 'if ok && match != a.Name && match != a.Exec {'
    '';

    excludedProviders = ["archlinuxpkgs" "dnfpackages"];

    buildPhase = ''
      runHook preBuild

      EXCLUDE_LIST="${prev.lib.concatStringsSep " " excludedProviders}"

      is_excluded() {
        target="$1"
        for e in $EXCLUDE_LIST; do
          [ -z "$e" ] && continue
          if [ "$e" = "$target" ]; then
            return 0
          fi
        done
        return 1
      }

      if [ -d ./internal/providers ]; then
        for dir in ./internal/providers/*; do
          [ -d "$dir" ] || continue
          provider=$(basename "$dir")
          if is_excluded "$provider"; then
            echo "Skipping excluded provider: $provider"
            continue
          fi
          set -- "$dir"/*.go
          if [ -e "$1" ]; then
            echo "Building provider: $provider"
            if ! go build -buildmode=plugin -o "$provider.so" ./internal/providers/"$provider"; then
              echo "Failed to build provider: $provider"
              exit 1
            fi
          else
            echo "Skipping $provider: no .go files found"
          fi
        done
      fi

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/elephant/providers
      for so_file in *.so; do
        [ -f "$so_file" ] && cp "$so_file" "$out/lib/elephant/providers/"
      done
      runHook postInstall
    '';
  };
in {
  elephant-with-providers = prev.stdenv.mkDerivation {
    pname = "elephant-with-providers";
    inherit version;
    dontUnpack = true;
    nativeBuildInputs = [prev.makeWrapper];
    installPhase = ''
      mkdir -p $out/bin $out/lib/elephant
      cp ${elephant-bin}/bin/elephant $out/bin/
      cp -r ${providers}/lib/elephant/providers $out/lib/elephant/
    '';
    postFixup = ''
      wrapProgram $out/bin/elephant \
        --prefix PATH : ${prev.lib.makeBinPath [prev.wl-clipboard prev.libqalculate prev.imagemagick prev.bluez]}
    '';
  };
})
