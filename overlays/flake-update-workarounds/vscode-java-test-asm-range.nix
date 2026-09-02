# jdtls never loads the Java test plugin: com.microsoft.java.test.plugin declares
# `Require-Bundle: org.objectweb.asm;bundle-version="[9.9.0,9.10.0)"` while
# jdt-language-server ships org.objectweb.asm_9.10.1 — one patch release past the
# exclusive upper bound. Equinox then can't resolve the bundle, so every Java
# session logs `BundleException: Could not resolve module:
# com.microsoft.java.test.plugin` and `nvim-jdtls` gets no test API at all.
#
# asm is compatible across 9.x, so widening the bound is enough; supplying a
# second asm instead would put two versions of it in one OSGi framework. The two
# packages are just a mismatched pair on this pin — nixpkgs bumping either side
# into agreement retires this.
# CHECK-RUNTIME: open a Java file — upstream is fixed when :LspLog has no "Could not resolve module: com.microsoft.java.test.plugin" for a fresh jdtls start.
_: _final: prev: {
  vscode-extensions =
    prev.vscode-extensions
    // {
      vscjava =
        prev.vscode-extensions.vscjava
        // {
          vscode-java-test = prev.vscode-extensions.vscjava.vscode-java-test.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.zip prev.unzip];
            # The range sits unfolded on one manifest line and 9.10.0 → 9.11.0 is
            # the same byte length, so no 72-column refolding is needed.
            postInstall =
              (old.postInstall or "")
              + ''
                cd "$out/share/vscode/extensions/vscjava.vscode-java-test/server"
                for jar in com.microsoft.java.test.plugin-*.jar; do
                  unzip -o -q "$jar" META-INF/MANIFEST.MF -d manifest
                  substituteInPlace manifest/META-INF/MANIFEST.MF \
                    --replace-fail 'org.objectweb.asm;bundle-version="[9.9.0,9.10.0)"' \
                    'org.objectweb.asm;bundle-version="[9.9.0,9.11.0)"'
                  (cd manifest && zip -q "../$jar" META-INF/MANIFEST.MF)
                  rm -rf manifest
                done
              '';
          });
        };
    };
}
