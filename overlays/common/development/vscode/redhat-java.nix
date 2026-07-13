# https://github.com/microsoft/vscode-gradle/issues/1589
# Patch the VSCode Java extension to use the Nix-provided JDK instead of the
# bundled dynamically-linked JRE.
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isLinux {
  vscode-marketplace-release =
    prev.vscode-marketplace-release
    // {
      redhat =
        prev.vscode-marketplace-release.redhat
        // {
          java = prev.vscode-marketplace-release.redhat.java.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                rm -rf $out/share/vscode/extensions/redhat.java/jre
                mkdir -p $out/share/vscode/extensions/redhat.java/jre
                ln -s ${prev.jdk21}/lib/openjdk $out/share/vscode/extensions/redhat.java/jre/21.0.9-linux-x86_64
              '';
          });
        };
    };
}
