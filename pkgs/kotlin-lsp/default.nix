{
  lib,
  stdenvNoCC,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  glibc,
  zlib,
  fontconfig,
  freetype,
  alsa-lib,
  libGL,
  glib,
  gtk3,
  libffi,
  cups,
  pango,
  cairo,
  gdk-pixbuf,
  libx11,
  libxext,
  libxrender,
  libxtst,
  libxt,
  libxi,
  libxinerama,
  libxcursor,
  libxrandr,
  libice,
  libsm,
}:
# Official JetBrains Kotlin Language Server (standalone), distributed as a
# prebuilt archive with its own bundled JetBrains Runtime and a native Rust
# launcher (bin/intellij-server). On NixOS the launcher + bundled JBR need
# autoPatchelfHook to fix their interpreters/rpaths.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kotlin-lsp";
  version = "262.7569.0";

  src = fetchzip {
    url = "https://download-cdn.jetbrains.com/kotlin-lsp/${finalAttrs.version}/kotlin-server-${finalAttrs.version}.tar.gz";
    hash = "sha256-u2IcSjMCAukvcDEZdvfyT6hWJJ+e5O49/SAWbqlXJyo=";
  };

  nativeBuildInputs = [autoPatchelfHook makeWrapper];

  buildInputs = [
    (lib.getLib stdenv.cc.cc) # libgcc_s, libstdc++
    glibc
    zlib
    fontconfig
    freetype
    alsa-lib
    libGL
    glib
    gtk3
    libffi
    cups
    pango
    cairo
    gdk-pixbuf
    libx11
    libxext
    libxrender
    libxtst
    libxt
    libxi
    libxinerama
    libxcursor
    libxrandr
    libice
    libsm
  ];

  # The launcher ships its own "self-contained"/musl-gcompat shim libs that
  # reference symbols absent on glibc; those are loaded by the launcher itself,
  # so don't fail the build when autoPatchelf can't resolve them.
  autoPatchelfIgnoreMissingDeps = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/kotlin-lsp $out/bin
    cp -r . $out/share/kotlin-lsp
    # lspconfig's kotlin_lsp invokes `kotlin-lsp --stdio`; expose that name.
    # The native launcher resolves IDE_HOME from its own path, so the tree
    # layout (bin/ jbr/ lib/ plugins/ modules/) must stay intact.
    makeWrapper $out/share/kotlin-lsp/bin/intellij-server $out/bin/kotlin-lsp
    runHook postInstall
  '';

  # Versions aren't discoverable from the JetBrains CDN src URL, so nix-update
  # can't auto-bump it. Point it at the GitHub releases instead, whose tags are
  # namespaced `kotlin-lsp/v<VERSION>` (the repo also carries unrelated
  # `pycharm/*` tags, which the regex skips).
  passthru.updateScript = [
    "nix-update"
    "--flake"
    "kotlin-lsp"
    "--version=stable"
    "--url=https://github.com/Kotlin/kotlin-lsp"
    "--version-regex"
    "kotlin-lsp/v([\\d.]+)"
  ];

  meta = {
    description = "Official JetBrains Kotlin Language Server (standalone)";
    homepage = "https://github.com/Kotlin/kotlin-lsp";
    license = lib.licenses.unfree; # bundles proprietary IntelliJ platform
    platforms = ["x86_64-linux"];
    mainProgram = "kotlin-lsp";
  };
})
