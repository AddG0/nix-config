# The configured Steam compatibility tool, republished where RLBot can find it.
#
# Core (Steam.Linux.cs) only globs <library>/steamapps/common for "Proton*", so a
# Nix compat tool in compatibilitytools.d is invisible and it falls back to stock
# Proton, which cannot run on NixOS. Placing the tree under a matching name is not
# enough: core then matches config.vdf's tool against toolmanifest.vdf's "nameid",
# which upstream manifests omit. Same tree, with a nameid added.
{
  runCommand,
  proton-ge-bin,
  # The name Steam has mapped to the game in config.vdf's CompatToolMapping.
  compatToolName ? "GE-Proton",
  # The tree that name resolves to. Pass the same one linked into
  # compatibilitytools.d, so changing the tool moves RLBot with it.
  proton ? proton-ge-bin.steamcompattool,
}:
runCommand "rlbot-proton-shim" {
  meta = {
    description = "A Steam compatibility tool republished under a name and manifest RLBot's Proton discovery accepts";
    platforms = ["x86_64-linux"];
  };
} ''
  mkdir -p "$out"

  for entry in ${proton}/*; do
    ln -s "$entry" "$out/$(basename "$entry")"
  done

  rm "$out/toolmanifest.vdf"
  sed '/^}/i\  "nameid" "${compatToolName}"' ${proton}/toolmanifest.vdf > "$out/toolmanifest.vdf"

  grep -q '"nameid"' "$out/toolmanifest.vdf" || {
    echo "toolmanifest.vdf did not gain a nameid; RLBot would ignore this tool" >&2
    exit 1
  }
''
