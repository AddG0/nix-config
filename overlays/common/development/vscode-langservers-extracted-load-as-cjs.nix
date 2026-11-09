# vscode-langservers-extracted 4.10.0 bundles mix CJS require() with ESM
# `createRequire(import.meta.url)`, so Node >=22 loads them as ESM and the
# top-level require() dies ("require is not defined in ES module scope").
# Rewrite import.meta.{url,dirname} to __filename/__dirname → pure CJS again.
_: _final: prev: {
  vscode-langservers-extracted = prev.vscode-langservers-extracted.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        find "$out" -type f -name '*.js' -path '*-language-server/*' \
          -exec sed -i 's/import\.meta\.url/__filename/g; s/import\.meta\.dirname/__dirname/g' {} +
      '';
  });
}
