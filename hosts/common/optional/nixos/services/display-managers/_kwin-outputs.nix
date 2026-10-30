# Renders display.monitors as KWin's kwinoutputconfig.json, filling each output's EDID hash from sysfs at run time.
{
  lib,
  pkgs,
}: monitors: let
  transforms = {
    normal = "Normal";
    "90" = "Rotated90";
    "180" = "Rotated180";
    "270" = "Rotated270";
    flipped = "Flipped";
    flipped-90 = "Flipped90";
    flipped-180 = "Flipped180";
    flipped-270 = "Flipped270";
  };

  secondaries = lib.filter (m: !m.primary) monitors;
  priorityOf = m:
    if m.primary
    then 0
    else 1 + lib.lists.findFirstIndex (s: s.output == m.output) null secondaries;

  template = pkgs.writeText "kwinoutputconfig-template.json" (builtins.toJSON [
    {
      name = "outputs";
      data =
        map (m: {
          connectorName = m.output;
          edidHash = "";
          inherit (m) scale;
          transform = transforms.${m.transform};
        })
        monitors;
    }
    {
      name = "setups";
      data = [
        {
          lidClosed = false;
          outputs =
            lib.imap0 (i: m: {
              inherit (m) enabled;
              outputIndex = i;
              position = {inherit (m) x y;};
              priority = priorityOf m;
            })
            monitors;
        }
      ];
    }
  ]);
in
  pkgs.writeShellApplication {
    name = "kwin-outputs";
    runtimeInputs = [pkgs.coreutils pkgs.jq];
    text = ''
      if [ $# -ne 2 ]; then
        echo "usage: kwin-outputs <drm sysfs dir> <kwinoutputconfig.json>" >&2
        exit 2
      fi
      drm=$1
      dest=$2

      # KWin matches a saved output by its EDID's md5, never by connector alone.
      shopt -s nullglob
      emptyMd5=d41d8cd98f00b204e9800998ecf8427e
      hashes=()
      connectors=(${lib.escapeShellArgs (map (m: m.output) monitors)})
      for connector in "''${connectors[@]}"; do
        hash=""
        # Several GPUs can share a connector name; a disconnected one has an empty edid.
        for edid in "$drm"/card*-"$connector"/edid; do
          candidate=$(md5sum < "$edid" | cut -d' ' -f1)
          if [ "$candidate" != "$emptyMd5" ]; then
            hash=$candidate
            break
          fi
        done
        if [ -z "$hash" ]; then
          echo "kwin-outputs: no EDID for $connector under $drm; KWin will ignore this layout and generate its own" >&2
        fi
        hashes+=("$hash")
      done

      mkdir -p "$(dirname "$dest")"
      jq '.[0].data |= [range(length) as $i | .[$i] + {edidHash: $ARGS.positional[$i]}]' \
        ${template} --args "''${hashes[@]}" > "$dest.tmp"
      mv "$dest.tmp" "$dest"
    '';
  }
