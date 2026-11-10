# ClickUp's update toast ends by closing every window (the updater is off), so the preload pre-fills the web app's skip key.
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  clickup = prev.clickup.overrideAttrs (old: let
    inherit (old) pname version;

    contents = prev.appimageTools.extract {
      inherit pname version;
      inherit (old.src) src;
      postExtract = ''
        asar=$out/resources/app.asar
        work=$(mktemp -d)
        chmod -R u+w $out/resources

        ${prev.asar}/bin/asar extract "$asar" "$work/app"
        if [ ! -f "$work/app/preload.js" ]; then
          echo "clickup-hide-update-toast: app.asar has no preload.js to append to; re-derive the patch for ${version}" >&2
          exit 1
        fi
        substitute ${./clickup-hide-update-toast.js} "$work/toast.js" --subst-var-by version ${version}
        if grep -q '@version@' "$work/toast.js"; then
          echo "clickup-hide-update-toast: @version@ left unsubstituted in toast.js" >&2
          exit 1
        fi
        cat "$work/toast.js" >> "$work/app/preload.js"

        unpackedBefore=$(cd "$asar.unpacked" && find . -type f | sort)
        unpackDirs=$(cd "$asar.unpacked" && find . -name package.json -printf '%h\n' | sed 's#^\./##' | sort -u | paste -sd,)
        rm -rf "$asar" "$asar.unpacked"
        ${prev.asar}/bin/asar pack "$work/app" "$asar" --unpack-dir "{$unpackDirs}"

        unpackedAfter=$(cd "$asar.unpacked" && find . -type f | sort)
        if [ "$unpackedBefore" != "$unpackedAfter" ]; then
          echo "clickup-hide-update-toast: repacked app.asar.unpacked no longer matches upstream's file list:" >&2
          diff <(echo "$unpackedBefore") <(echo "$unpackedAfter") >&2
          exit 1
        fi
      '';
    };
  in {
    src = prev.appimageTools.wrapAppImage {
      inherit pname version contents;
      extraPkgs = pkgs: [pkgs.libxkbfile];
    };
  });
}
