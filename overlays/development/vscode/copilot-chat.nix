# Fix Copilot Chat on read-only Nix store:
# 1. ensureShims() copies node-pty + ripgrep into extension node_modules at
#    runtime, which fails on the Nix store. Pre-create the shims at build time
#    from VS Code's bundled copies and write the marker so ensureShims skips.
# 2. copyFile from Nix store preserves read-only perms — chmod writable after.
_: _final: prev: {
  vscode-marketplace-release =
    prev.vscode-marketplace-release
    // {
      github =
        prev.vscode-marketplace-release.github
        // {
          copilot-chat = prev.vscode-marketplace-release.github.copilot-chat.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                extDir="$out/share/vscode/extensions/github.copilot-chat"
                extJs="$extDir/dist/extension.js"
                sdkDir="$extDir/node_modules/@github/copilot/sdk"

                # Pre-create node-pty shim (SQn) — must be a copy, not symlink,
                # because Electron blocks native module loads from outside the app.
                mkdir -p "$sdkDir/prebuilds/linux-x64"
                cp "${prev.vscode}/lib/vscode/resources/app/node_modules/node-pty/build/Release/pty.node" \
                  "$sdkDir/prebuilds/linux-x64/pty.node"

                # Pre-create ripgrep shim (TQn). VS Code 1.122 renamed the
                # bundled package @vscode/ripgrep -> @vscode/ripgrep-universal
                # and moved the binary under bin/linux-x64/.
                mkdir -p "$sdkDir/ripgrep/bin/linux-x64"
                cp "${prev.vscode}/lib/vscode/resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg" \
                  "$sdkDir/ripgrep/bin/linux-x64/rg"

                # Write marker so ensureShims() skips at runtime
                echo "Shims created successfully" > "$extDir/node_modules/@github/copilot/shims.txt"

                # chmod copied files writable (Nix store sources are read-only).
                # Regex matches copyFile calls regardless of minified variable names.
                sed -i -E 's/await ([a-zA-Z0-9]+)\.promises\.copyFile\(jr\(__dirname,MQt\),jr\(([a-zA-Z0-9]+),MQt\)\)/await \1.promises.copyFile(jr(__dirname,MQt),jr(\2,MQt)),await \1.promises.chmod(jr(\2,MQt),438)/g' "$extJs"
              '';
          });
        };
    };
}
