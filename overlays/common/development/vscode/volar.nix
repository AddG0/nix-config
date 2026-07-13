# Fix Volar activation crash on read-only Nix store. Volar's bi() unconditionally
# calls writeFileSync to create vue-typescript-plugin-pack/index.js. Guard the
# write with existsSync and pre-create the file at build time.
_: _final: prev: {
  vscode-marketplace =
    prev.vscode-marketplace
    // {
      vue =
        prev.vscode-marketplace.vue
        // {
          volar = prev.vscode-marketplace.vue.volar.overrideAttrs (old: {
            postInstall =
              (old.postInstall or "")
              + ''
                extJs="$out/share/vscode/extensions/vue.volar/dist/extension.js"

                # Guard writeFileSync with existsSync so it skips when file is pre-created
                substituteInPlace "$extJs" \
                  --replace-fail \
                    'r.writeFileSync(t,`try { module.exports = require("../@vue/typescript-plugin"); } catch { module.exports = require("../../dist/typescript-plugin.js"); }`)' \
                    'r.existsSync(t)||r.writeFileSync(t,`try { module.exports = require("../@vue/typescript-plugin"); } catch { module.exports = require("../../dist/typescript-plugin.js"); }`)'

                # Pre-create the plugin shim so the guard above skips at runtime
                pluginDir="$out/share/vscode/extensions/vue.volar/node_modules/vue-typescript-plugin-pack"
                mkdir -p "$pluginDir"
                cat > "$pluginDir/index.js" <<'PLUGIN'
                try { module.exports = require("../@vue/typescript-plugin"); } catch { module.exports = require("../../dist/typescript-plugin.js"); }
                PLUGIN
              '';
          });
        };
    };
}
