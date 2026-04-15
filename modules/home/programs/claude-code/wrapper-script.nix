{
  baseDir,
  cfg,
  lib,
  pkgs,
  resolvedProfiles,
}: let
  pluginDirsCase = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      name: profile: let
        resolved = resolvedProfiles.${name};
        dirs = resolved.pluginDirs or [];
      in
        lib.optionalString (dirs != []) ''
          ${name}) ${lib.concatMapStringsSep " " (d: ''PLUGIN_ARGS+=(--plugin-dir "${d}")'') dirs} ;;''
    )
    cfg.profiles);

  wrapperScript = pkgs.writeShellScriptBin "claude" ''
    PROFILE="${cfg.defaultProfile}"
    ARGS=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --profile|-P)
          if [[ -n "$2" && ! "$2" =~ ^- ]]; then
            PROFILE="$2"
            shift 2
          else
            echo "Error: --profile requires a profile name" >&2
            exit 1
          fi
          ;;
        --profile=*) PROFILE="''${1#--profile=}"; shift ;;
        -P=*) PROFILE="''${1#-P=}"; shift ;;
        --list-profiles)
          echo "Available profiles:"
          for dir in "$HOME/${baseDir}"/*/; do
            [ -d "$dir" ] && echo "  - $(basename "$dir")"
          done
          exit 0
          ;;
        *) ARGS+=("$1"); shift ;;
      esac
    done

    PROFILE_DIR="$HOME/${baseDir}/$PROFILE"

    if [[ ! -d "$PROFILE_DIR" ]]; then
      echo "Error: Profile '$PROFILE' not found at $PROFILE_DIR" >&2
      echo "Available profiles:"
      for dir in "$HOME/${baseDir}"/*/; do
        [ -d "$dir" ] && echo "  - $(basename "$dir")"
      done
      exit 1
    fi

    export CLAUDE_CONFIG_DIR="$PROFILE_DIR"

    MCP_ARGS=()
    if [[ -f "$PROFILE_DIR/.mcp.json" ]]; then
      MCP_ARGS+=(--mcp-config "$PROFILE_DIR/.mcp.json")
    fi

    PLUGIN_ARGS=()
    case "$PROFILE" in
    ${pluginDirsCase}
      *) ;;
    esac

    if [[ -d "$PROFILE_DIR/plugins/lsp" ]]; then
      PLUGIN_ARGS+=(--plugin-dir "$PROFILE_DIR/plugins/lsp")
    fi

    exec ${cfg.package}/bin/claude "''${MCP_ARGS[@]}" "''${PLUGIN_ARGS[@]}" "''${ARGS[@]}"
  '';
in {
  inherit pluginDirsCase wrapperScript;
}
