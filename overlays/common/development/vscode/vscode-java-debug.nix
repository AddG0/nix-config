# Fix debug extensions writing .noConfigDebugAdapterEndpoints to the read-only
# extension dir; redirect to XDG_STATE_HOME. Regex survives minified renames.
_: _final: prev: {
  vscode-marketplace-release =
    prev.vscode-marketplace-release
    // {
      vscjava =
        prev.vscode-marketplace-release.vscjava
        // {
          vscode-java-debug = prev.vscode-marketplace-release.vscjava.vscode-java-debug.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                sed -i -E 's/([a-zA-Z0-9]+)\.join\([a-zA-Z0-9]+,"\.noConfigDebugAdapterEndpoints"\)/\1.join(process.env.XDG_STATE_HOME||(process.env.HOME+"\/.local\/state"),"vscode-java-debug")/g' \
                  $out/share/vscode/extensions/vscjava.vscode-java-debug/dist/extension.js
              '';
          });
        };
    };
}
