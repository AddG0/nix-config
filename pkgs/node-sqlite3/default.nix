{
  stdenv,
  fetchFromGitHub,
  fetchurl,
  nodejs,
  python3,
  pkg-config,
  sqlite,
  lib,
  nodePackages,
}: let
  src = fetchFromGitHub {
    owner = "TryGhost";
    repo = "node-sqlite3";
    rev = "v5.1.7";
    hash = "sha256-UAYWr/bjRWCBw/8ThmFVvgpJxnU8WGAfVJBN1BCEUrw=";
  };

  # Runtime deps fetched as tarballs for the sandbox
  bindings = fetchurl {
    url = "https://registry.npmjs.org/bindings/-/bindings-1.5.0.tgz";
    hash = "sha256-13eBF4xb2JqRsfbFVWrNURsbWSfrE+KtgYnKwp7rCQc=";
  };
  file-uri-to-path = fetchurl {
    url = "https://registry.npmjs.org/file-uri-to-path/-/file-uri-to-path-1.0.0.tgz";
    hash = "sha256-VEDN9n51q5bzamvmPB1MPVQlWx0JcCc3EP7P6/qwb7M=";
  };
  node-addon-api = fetchurl {
    url = "https://registry.npmjs.org/node-addon-api/-/node-addon-api-7.1.1.tgz";
    hash = "sha256-sQRV0VqXfAzRehyw62eeA9k5+O+NQwLrM+H3jazHH4I=";
  };
in
  stdenv.mkDerivation {
    pname = "node-sqlite3";
    version = "5.1.7";
    inherit src;

    nativeBuildInputs = [nodejs python3 pkg-config nodePackages.node-gyp];
    buildInputs = [sqlite nodejs];

    postPatch = ''
      # Install runtime deps manually (no network in sandbox)
      mkdir -p node_modules/bindings node_modules/file-uri-to-path node_modules/node-addon-api
      tar xzf ${bindings} --strip-components=1 -C node_modules/bindings
      tar xzf ${file-uri-to-path} --strip-components=1 -C node_modules/file-uri-to-path
      tar xzf ${node-addon-api} --strip-components=1 -C node_modules/node-addon-api
    '';

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      node-gyp rebuild --nodedir=${nodejs}/include/node --build-from-source --sqlite=${sqlite}
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/sqlite3
      cp -r lib package.json node_modules build $out/lib/node_modules/sqlite3/
      runHook postInstall
    '';

    meta = {
      description = "Asynchronous, non-blocking SQLite3 bindings for Node.js";
      license = lib.licenses.bsd3;
    };
  }
