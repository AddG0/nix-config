# Fix google-java-format-for-vs-code on read-only Nix store:
# 1. Cache lives under context.extensionUri (read-only) → redirect to
#    context.globalStorageUri which VSCode guarantees is writable.
# 2. enableExecutionPermission() unconditionally runs `chmod +x` on the binary
#    path; nixpkgs binaries are already +x and the path is read-only, so
#    neutralize the call. Both substitutions are unique in the bundle.
_: _final: prev: {
  vscode-marketplace =
    prev.vscode-marketplace
    // {
      josevseb =
        prev.vscode-marketplace.josevseb
        // {
          google-java-format-for-vs-code = prev.vscode-marketplace.josevseb.google-java-format-for-vs-code.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                extJs="$out/share/vscode/extensions/josevseb.google-java-format-for-vs-code/dist/extension.js"
                sed -i 's/\.extensionUri/\.globalStorageUri/g' "$extJs"
                sed -i -E 's|\(0,[A-Za-z_$0-9]+\.execFileSync\)\("chmod",\[[^]]*\],\{[^}]*\}\)|null|g' "$extJs"
              '';
          });
        };
    };
}
