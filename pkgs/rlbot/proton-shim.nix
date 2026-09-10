# The configured Steam compatibility tool, republished where RLBot can find it.
#
# Core (Steam.Linux.cs) only globs <library>/steamapps/common for "Proton*", so a
# Nix compat tool in compatibilitytools.d is invisible and it falls back to stock
# Proton, which cannot run on NixOS. Placing the tree under a matching name is not
# enough: core then matches config.vdf's tool against toolmanifest.vdf's "nameid",
# which upstream manifests omit. Same tree, with a nameid added.
{
  lib,
  runCommand,
  writeShellScript,
  proton-ge-bin,
  # The name Steam has mapped to the game in config.vdf's CompatToolMapping.
  compatToolName ? "GE-Proton",
  # The tree that name resolves to. Pass the same one linked into
  # compatibilitytools.d, so changing the tool moves RLBot with it.
  proton ? proton-ge-bin.steamcompattool,
  # BakkesMod's injector, started with the game and killed with it. Steam has no
  # appmanifest for this tree, so only core ever reaches the entry point below.
  injector ? null,
}: let
  # Training runs a core per game instance and wants no BakkesMod window on any
  # of them; NO_BAKKESMOD=1 in that core's environment turns this off.
  #
  # No --no-wait: BakkesMod verifies the build id against Rocket League's own
  # Launch.log, so starting it with the game costs a retry cycle before it loads.
  startInjector = lib.optionalString (injector != null) ''
    if [ "''${NO_BAKKESMOD:-0}" = 0 ]; then
      ${lib.getExe' injector "bakkes-inject"} --tool ${proton} &
      injector_pid=$!
      cleanup() { kill "$injector_pid" 2>/dev/null || true; }
      # A bare TERM would otherwise skip the EXIT trap and leave BakkesMod behind.
      trap cleanup EXIT
      trap 'cleanup; exit 143' TERM INT
    fi
  '';

  entryPoint = writeShellScript "proton" ''
    case "$*" in
      # BakkesMod cannot inject into the anti-cheat build; core never launches it.
      *RocketLeague_EAC.exe*) ;;
      # --tool is the real tool: pointing it here would re-enter this script
      # for BakkesMod and start a second injector.
      *RocketLeague.exe*)
        ${startInjector}
        ;;
    esac

    ${proton}/proton "$@"
  '';
in
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

    ${lib.optionalString (injector != null) ''
      rm "$out/proton"
      install -m755 ${entryPoint} "$out/proton"
    ''}
  ''
