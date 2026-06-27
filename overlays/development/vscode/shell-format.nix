# Fix shell-format 7.2.8 missing @one-ini/wasm runtime. Without one_ini_bg.wasm
# in dist/, the extension fails to register as a formatter and VSCode reports
# "There is no formatter for shellscript".
# Upstream bug: https://github.com/foxundermoon/vs-shell-format/issues/396
_: _final: prev: {
  vscode-marketplace =
    prev.vscode-marketplace
    // {
      foxundermoon =
        prev.vscode-marketplace.foxundermoon
        // {
          shell-format = prev.vscode-marketplace.foxundermoon.shell-format.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                cp ${prev.fetchurl {
                  url = "https://unpkg.com/@one-ini/wasm@0.1.1/one_ini_bg.wasm";
                  sha256 = "0w5242acw54ykf7xyfrf1z1yzwgbf9mf9gz450p71rhcqkxrmby5";
                }} $out/share/vscode/extensions/foxundermoon.shell-format/dist/one_ini_bg.wasm
              '';
          });
        };
    };
}
