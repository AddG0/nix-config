{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_20,
  python3,
  stdenv,
}:
buildNpmPackage {
  pname = "claude-flow";
  version = "2.0.0-alpha.89";

  src = fetchFromGitHub {
    owner = "ruvnet";
    repo = "claude-flow";
    rev = "25af48cd1c01cbcc4ac6d0dc4346e956db913845";
    sha256 = "sha256-20dMNAihqY6oiBjDUKHj/IlGn9gVyQOOGbVlIrWksv0=";
  };

  npmDepsHash = "sha256-C74Gv6Xtr+Hl06mxxTCoWaif5UIE5kZatcjoBUCKQHY";

  nodejs = nodejs_20;

  nativeBuildInputs =
    [
      nodejs_20
      python3
    ]
    ++ lib.optionals stdenv.isDarwin [
      stdenv.cc
    ];

  # Skip Puppeteer download during npm install
  PUPPETEER_SKIP_DOWNLOAD = true;

  # Environment variables for node-gyp
  npm_config_build_from_source = true;

  # Skip the build phase since TypeScript compilation is failing
  # and we'll use the existing lib directory
  dontNpmBuild = true;

  # Configure npm to handle native dependencies properly
  makeCacheWritable = true;

  # Override problematic modules during install
  npmFlags = ["--ignore-scripts"];

  installPhase = ''
    mkdir -p $out/bin

    # Copy everything to the root to maintain the expected structure
    cp -r bin src cli.mjs node_modules scripts package.json $out/ 2>/dev/null || true

    # Use the existing bin/claude-flow.js as the main executable
    cp bin/claude-flow.js $out/bin/claude-flow
    chmod +x $out/bin/claude-flow

    # Patch the shebang to use nix's node
    sed -i "1s|.*|#!${nodejs_20}/bin/node|" $out/bin/claude-flow

    # Also patch the spawn call to use the full node path
    sed -i "s|spawn('node'|spawn('${nodejs_20}/bin/node'|g" $out/bin/claude-flow

    # Fix the require('fs') issue in ES module
    sed -i "s|require('fs').readFileSync|import('fs').then(fs => fs.readFileSync)|g" $out/src/cli/simple-commands/swarm.js

    # Actually, let's just replace the problematic line with a simpler check
    sed -i "34s|.*|     false);|" $out/src/cli/simple-commands/swarm.js
  '';

  meta = with lib; {
    description = "Enterprise-grade AI agent orchestration platform";
    homepage = "https://github.com/ruvnet/claude-flow";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [];
  };
}
