# Rust (crane + rust-overlay) Reference

Use when the project uses `cargo` for Rust dependency management (has `Cargo.toml` + `Cargo.lock`).

## Additional Inputs

Merge into the base flake template's `inputs`:

```nix
crane.url = "github:ipetkov/crane";
rust-overlay = {
  url = "github:oxalica/rust-overlay";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## perSystem Pattern

Replace the base template's `perSystem` with this structure:

```nix
perSystem = {
  config,
  pkgs,
  system,
  ...
}: let
  rust = pkgs.rust-bin.stable.latest.default;
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rust;

  src = craneLib.cleanCargoSource ./.;

  commonArgs = {
    inherit src;
    strictDeps = true;
    # For projects with native deps, add here:
    # nativeBuildInputs = [pkgs.pkg-config pkgs.protobuf];
    # buildInputs = [pkgs.openssl pkgs.dbus];
  };

  # Cache deps as their own layer so source changes don't redo them
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  my-package = craneLib.buildPackage (commonArgs
    // {
      inherit cargoArtifacts;
      meta = {
        mainProgram = "my-binary";
      };
    });
in {
  # rust-overlay attaches the rust-bin attrset to pkgs
  _module.args.pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [inputs.rust-overlay.overlays.default];
  };

  pre-commit.settings.hooks = {
    alejandra.enable = true;
    rustfmt = {
      enable = true;
      packageOverrides.rustfmt = rust;
    };
    clippy = {
      enable = true;
      packageOverrides = {
        cargo = rust;
        clippy = rust;
      };
    };
  };

  packages = {
    default = my-package;
    inherit my-package;
  };

  checks = {
    inherit my-package;
  };

  formatter = pkgs.alejandra;

  devShells.default = craneLib.devShell {
    inputsFrom = [my-package];
    packages = with pkgs; [
      rust-analyzer
    ];
    shellHook = ''
      ${config.pre-commit.installationScript}
    '';
  };
};
```

## Conventions

- `crane` orchestrates cargo with Nix-friendly caching; `rust-overlay` provides pinned/specific Rust toolchains
- `pkgs.rust-bin.stable.latest.default` — use `.stable."<ver>".default`, `.beta.latest.default`, or `.nightly.latest.default` to change channel/version
- `buildDepsOnly` is built separately so source-only changes skip re-resolving dependencies
- `craneLib.cleanCargoSource ./.` strips non-Rust/Cargo files for stable hashing — replace with a custom `cleanSourceWith` if extra files are needed in the build (e.g. `.proto`)
- `packageOverrides` on the `clippy` and `rustfmt` hooks pins them to the same toolchain as the build, preventing version drift
- `craneLib.devShell` over `pkgs.mkShell` — automatically wires `cargoArtifacts`, sets `RUST_SRC_PATH` for rust-analyzer, and applies `inputsFrom` build deps

## Customization Points

### Pinned toolchain version

```nix
# Exact stable version
rust = pkgs.rust-bin.stable."1.78.0".default;

# Honor a project's rust-toolchain.toml
rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
```

### Native dependencies

Add to `commonArgs` (and reuse in `devShells.default.packages` for direct binary access):

```nix
commonArgs = {
  inherit src;
  strictDeps = true;
  nativeBuildInputs = [pkgs.pkg-config pkgs.protobuf];
  buildInputs = [pkgs.openssl pkgs.dbus];
  # For tonic-build / prost / anything that shells out to protoc:
  PROTOC = "${pkgs.protobuf}/bin/protoc";
};
```

### Including non-Rust source files

`cleanCargoSource` strips everything except Cargo/Rust files. For `.proto`, `.sql`, schemas, etc., use a custom filter:

```nix
src = pkgs.lib.cleanSourceWith {
  src = craneLib.path ./.;
  filter = path: type:
    (pkgs.lib.hasSuffix ".proto" path)
    || (craneLib.filterCargoSources path type);
};
```

### Offline clippy in `nix flake check`

`nix flake check` has no network. If the pre-commit clippy hook fetches crate metadata, vendor deps with crane and prime `CARGO_HOME`:

```nix
cargoVendorDir = craneLib.vendorCargoDeps {inherit src;};

clippyOffline = pkgs.writeShellApplication {
  name = "cargo-clippy-offline";
  runtimeInputs = [rust];
  text = ''
    CARGO_HOME=$(mktemp -d)
    cp ${cargoVendorDir}/config.toml "$CARGO_HOME/config.toml"
    export CARGO_HOME
    exec cargo-clippy clippy --all-targets --offline "$@" -- --deny warnings
  '';
};

pre-commit.settings.hooks.clippy = {
  enable = true;
  entry = pkgs.lib.mkForce "${clippyOffline}/bin/cargo-clippy-offline";
  files = "\\.rs$";
  pass_filenames = false;
};
```

### Cargo workspaces

`craneLib.buildPackage` builds one package. For a workspace, pass `cargoExtraArgs = "-p <pkg>"` in `commonArgs`, or use `craneLib.cargoBuild` directly to build everything.

### Darwin support

If targeting macOS, add Darwin frameworks to `buildInputs`:

```nix
buildInputs =
  [pkgs.openssl]
  ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    pkgs.darwin.apple_sdk.frameworks.Security
    pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
  ];
```
